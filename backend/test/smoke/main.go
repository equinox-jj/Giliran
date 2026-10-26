// Command smoke measures API latency against the PRD §10 targets: p95 under
// 300 ms for reads and 600 ms for writes.
//
//	go run ./test/smoke -base-url http://localhost:8080
//
// It reads .env like the API (DATABASE_URL and JWT_SECRET must match the
// server under test), seeds accounts straight into Postgres because sign-in
// needs Firebase, mints their access tokens, and drives one started group
// over HTTP. It writes data, so it refuses APP_ENV=production unless -force
// is set; point it at a dev or staging stack. Seeded users have +62899…
// phones and stay behind.
//
// Every user stays under RATE_LIMIT_WRITE_MAX: -requests per write endpoint
// times four write endpoints must fit in one write window.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"math/rand/v2"
	"mime/multipart"
	"net/http"
	"os"
	"slices"
	"sort"
	"sync"
	"text/tabwriter"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/equinox-jj/Giliran/backend/pkg/clock"
	"github.com/equinox-jj/Giliran/backend/pkg/config"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
	"github.com/equinox-jj/Giliran/backend/pkg/utils"
)

type options struct {
	baseURL     string
	users       int
	requests    int
	concurrency int
	readP95     time.Duration
	writeP95    time.Duration
	force       bool
}

func main() {
	var o options
	flag.StringVar(&o.baseURL, "base-url", "http://localhost:8080", "API origin")
	flag.IntVar(&o.users, "users", 10, "accounts in the group (2-50)")
	flag.IntVar(&o.requests, "requests", 10, "requests per endpoint per user")
	flag.IntVar(&o.concurrency, "concurrency", 8, "requests in flight")
	flag.DurationVar(&o.readP95, "read-p95", 300*time.Millisecond, "read p95 target")
	flag.DurationVar(&o.writeP95, "write-p95", 600*time.Millisecond, "write p95 target")
	flag.BoolVar(&o.force, "force", false, "run even when APP_ENV=production")
	flag.Parse()

	if err := run(context.Background(), o); err != nil {
		fmt.Fprintln(os.Stderr, "smoke:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, o options) error {
	if o.users < 2 || o.users > 50 {
		return fmt.Errorf("-users must be between 2 and 50, got %d", o.users)
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if cfg.App.IsProduction() && !o.force {
		return fmt.Errorf("APP_ENV=production: the smoke test writes data; pass -force to run it anyway")
	}
	if need := o.requests * 4; need > cfg.RateLimit.WriteMax {
		fmt.Fprintf(os.Stderr, "warning: %d writes per user exceed RATE_LIMIT_WRITE_MAX=%d; expect 429s\n", need, cfg.RateLimit.WriteMax)
	}

	c := &client{base: o.baseURL, http: &http.Client{Timeout: 30 * time.Second, Transport: &http.Transport{MaxIdleConnsPerHost: o.concurrency}}}
	users, err := seedUsers(ctx, cfg, o.users)
	if err != nil {
		return err
	}
	g, err := setUpGroup(ctx, c, cfg, users)
	if err != nil {
		return err
	}

	fmt.Printf("group %s: %d members, period %s\n", g.id, len(users), g.periodID)
	samples := load(ctx, c, o, g, users)
	return report(samples, o)
}

// user is a seeded account with its access token.
type user struct {
	id        uuid.UUID
	token     string
	memberID  string
	paymentID string
}

func seedUsers(ctx context.Context, cfg *config.Config, n int) ([]*user, error) {
	pool, err := pgxpool.New(ctx, cfg.Database.URL)
	if err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	defer pool.Close()
	tokens := security.NewTokenIssuer(cfg, clock.System{})
	// A random block of phone numbers, so reruns do not collide.
	base := rand.IntN(90_000_000) //nolint:gosec // test data, not a secret
	users := make([]*user, n)
	for i := range users {
		u := &user{id: uuid.Must(uuid.NewV7())}
		phone := fmt.Sprintf("+62899%08d", base+i)
		if _, err := pool.Exec(ctx, `INSERT INTO users (id, phone, name) VALUES ($1, $2, $3)`, u.id, phone, fmt.Sprintf("Smoke %02d", i+1)); err != nil {
			return nil, fmt.Errorf("insert user: %w", err)
		}
		if _, err := pool.Exec(ctx, `INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, u.id); err != nil {
			return nil, fmt.Errorf("insert settings: %w", err)
		}
		if u.token, _, err = tokens.Issue(u.id, uuid.Must(uuid.NewV7())); err != nil {
			return nil, err
		}
		users[i] = u
	}
	return users, nil
}

type group struct {
	id       string
	periodID string
}

// setUpGroup has users[0] create a random-draw group the size of users, the
// others join it, then it is started; each user learns their payment.
func setUpGroup(ctx context.Context, c *client, cfg *config.Config, users []*user) (group, error) {
	org := users[0]
	start := utils.Today(time.Now(), cfg.App.Location).AddDate(0, 0, 7).Format(time.DateOnly)
	var created struct {
		ID         string `json:"id"`
		MyMemberID string `json:"my_member_id"`
		Invite     struct {
			InviteCode string `json:"invite_code"`
		} `json:"invite"`
	}
	body := fmt.Sprintf(`{"name":"Smoke test","amount":100000,"period_type":"monthly","total_slots":%d,"start_date":%q,"draw_method":"random"}`, len(users), start)
	if err := c.must(ctx, org, http.MethodPost, "/api/v1/groups", jsonReq(body), http.StatusCreated, &created); err != nil {
		return group{}, err
	}
	org.memberID = created.MyMemberID
	g := group{id: created.ID}
	for _, u := range users[1:] {
		var m struct {
			ID string `json:"id"`
		}
		if err := c.must(ctx, u, http.MethodPost, "/api/v1/invites/"+created.Invite.InviteCode+"/join", request{}, http.StatusCreated, &m); err != nil {
			return group{}, err
		}
		u.memberID = m.ID
	}
	info := `{"bank_name":"BCA","account_number":"1234567890","account_holder":"Smoke Test"}`
	if err := c.must(ctx, org, http.MethodPut, "/api/v1/groups/"+g.id+"/payment-info", jsonReq(info), http.StatusOK, nil); err != nil {
		return group{}, err
	}
	var started struct {
		CurrentPeriodID string `json:"current_period_id"`
	}
	if err := c.must(ctx, org, http.MethodPost, "/api/v1/groups/"+g.id+"/start", request{}, http.StatusOK, &started); err != nil {
		return group{}, err
	}
	g.periodID = started.CurrentPeriodID
	var board []struct {
		ID     string `json:"id"`
		Member struct {
			ID string `json:"id"`
		} `json:"member"`
	}
	if err := c.must(ctx, org, http.MethodGet, "/api/v1/groups/"+g.id+"/periods/"+g.periodID+"/payments", request{}, http.StatusOK, &board); err != nil {
		return group{}, err
	}
	for _, u := range users {
		for _, p := range board {
			if p.Member.ID == u.memberID {
				u.paymentID = p.ID
			}
		}
		if u.paymentID == "" {
			return group{}, fmt.Errorf("no payment for member %s", u.memberID)
		}
	}
	return g, nil
}

// endpoint is one measured request; build returns a fresh body each time.
type endpoint struct {
	name    string
	write   bool
	orgOnly bool
	method  string
	path    func(g group, u *user) string
	build   func() request
}

func endpoints() []endpoint {
	gp := func(suffix string) func(group, *user) string {
		return func(g group, _ *user) string { return "/api/v1/groups/" + g.id + suffix }
	}
	pp := func(suffix string) func(group, *user) string {
		return func(g group, _ *user) string { return "/api/v1/groups/" + g.id + "/periods/" + g.periodID + suffix }
	}
	fixed := func(p string) func(group, *user) string { return func(group, *user) string { return p } }
	return []endpoint{
		{name: "GET /me", method: http.MethodGet, path: fixed("/api/v1/me")},
		{name: "GET /me/groups", method: http.MethodGet, path: fixed("/api/v1/me/groups")},
		{name: "GET /groups/{id}", method: http.MethodGet, path: gp("")},
		{name: "GET /groups/{id}/members", method: http.MethodGet, path: gp("/members")},
		{name: "GET /groups/{id}/periods", method: http.MethodGet, path: gp("/periods")},
		{name: "GET .../payments (board)", method: http.MethodGet, path: pp("/payments")},
		{name: "GET /groups/{id}/activity", method: http.MethodGet, path: gp("/activity")},
		{name: "GET /groups/{id}/obligations", method: http.MethodGet, path: gp("/obligations")},
		{name: "PATCH /me", write: true, method: http.MethodPatch, path: fixed("/api/v1/me"),
			build: func() request { return jsonReq(fmt.Sprintf(`{"name":"Smoke %04d"}`, rand.IntN(10_000))) }}, //nolint:gosec // test data
		{name: "PATCH /me/settings", write: true, method: http.MethodPatch, path: fixed("/api/v1/me/settings"),
			build: func() request { return jsonReq(fmt.Sprintf(`{"notify_group_activity":%t}`, rand.IntN(2) == 0)) }}, //nolint:gosec // test data
		{name: "POST .../proofs", write: true, method: http.MethodPost,
			path: func(g group, u *user) string {
				return "/api/v1/groups/" + g.id + "/payments/" + u.paymentID + "/proofs"
			},
			build: proofReq},
		{name: "POST .../reminders", write: true, orgOnly: true, method: http.MethodPost, path: pp("/reminders"),
			build: func() request { return jsonReq(`{}`) }},
	}
}

type sample struct {
	endpoint string
	write    bool
	latency  time.Duration
	status   int
	err      error
}

// load runs every endpoint -requests times per user, shuffled, with
// -concurrency requests in flight.
func load(ctx context.Context, c *client, o options, g group, users []*user) []sample {
	type job struct {
		e endpoint
		u *user
	}
	var jobs []job
	for _, e := range endpoints() {
		for i, u := range users {
			if e.orgOnly && i > 0 {
				continue
			}
			for range o.requests {
				jobs = append(jobs, job{e, u})
			}
		}
	}
	rand.Shuffle(len(jobs), func(i, j int) { jobs[i], jobs[j] = jobs[j], jobs[i] }) //nolint:gosec // request order, not a secret

	queue := make(chan job)
	out := make(chan sample, len(jobs))
	var wg sync.WaitGroup
	for range o.concurrency {
		wg.Go(func() {
			for j := range queue {
				var r request
				if j.e.build != nil {
					r = j.e.build()
				}
				status, latency, err := c.do(ctx, j.u, j.e.method, j.e.path(g, j.u), r, nil)
				out <- sample{endpoint: j.e.name, write: j.e.write, latency: latency, status: status, err: err}
			}
		})
	}
	start := time.Now()
	for _, j := range jobs {
		queue <- j
	}
	close(queue)
	wg.Wait()
	close(out)
	fmt.Printf("%d requests in %s\n\n", len(jobs), time.Since(start).Round(time.Millisecond))

	samples := make([]sample, 0, len(jobs))
	for s := range out {
		samples = append(samples, s)
	}
	return samples
}

// report prints the latency table and fails on a missed target or any 5xx.
func report(samples []sample, o options) error {
	byName := map[string][]sample{}
	var names []string
	for _, s := range samples {
		if _, ok := byName[s.endpoint]; !ok {
			names = append(names, s.endpoint)
		}
		byName[s.endpoint] = append(byName[s.endpoint], s)
	}
	sort.Strings(names)

	tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', tabwriter.AlignRight)
	fmt.Fprintln(tw, "endpoint\tn\t4xx\t5xx/err\tp50\tp95\tp99\t")
	row := func(name string, ss []sample) {
		st := summarize(ss)
		fmt.Fprintf(tw, "%s\t%d\t%d\t%d\t%s\t%s\t%s\t\n", name, len(ss), st.client, st.server, ms(st.p50), ms(st.p95), ms(st.p99))
	}
	for _, n := range names {
		row(n, byName[n])
	}
	var reads, writes []sample
	for _, s := range samples {
		if s.write {
			writes = append(writes, s)
		} else {
			reads = append(reads, s)
		}
	}
	fmt.Fprintln(tw, "\t\t\t\t\t\t\t")
	row("ALL READS", reads)
	row("ALL WRITES", writes)
	if err := tw.Flush(); err != nil {
		return err
	}

	var failed []string
	r, w := summarize(reads), summarize(writes)
	if r.p95 > o.readP95 {
		failed = append(failed, fmt.Sprintf("read p95 %s over %s", ms(r.p95), ms(o.readP95)))
	}
	if w.p95 > o.writeP95 {
		failed = append(failed, fmt.Sprintf("write p95 %s over %s", ms(w.p95), ms(o.writeP95)))
	}
	if n := r.server + w.server; n > 0 {
		failed = append(failed, fmt.Sprintf("%d requests failed with 5xx or a transport error", n))
		for _, s := range samples {
			if s.err != nil {
				failed = append(failed, "first error: "+s.err.Error())
				break
			}
		}
	}
	if n := r.client + w.client; n > 0 {
		fmt.Printf("\nnote: %d requests got a 4xx (a 429 means the rate limit is lower than the load)\n", n)
	}
	if len(failed) > 0 {
		return fmt.Errorf("targets missed:\n  %s", joinLines(failed))
	}
	fmt.Printf("\nPASS: read p95 %s (target %s), write p95 %s (target %s)\n", ms(r.p95), ms(o.readP95), ms(w.p95), ms(o.writeP95))
	return nil
}

type stats struct {
	p50, p95, p99  time.Duration
	client, server int
}

func summarize(ss []sample) stats {
	var st stats
	lat := make([]time.Duration, 0, len(ss))
	for _, s := range ss {
		switch {
		case s.err != nil || s.status >= 500:
			st.server++
		case s.status >= 400:
			st.client++
		}
		lat = append(lat, s.latency)
	}
	slices.Sort(lat)
	st.p50, st.p95, st.p99 = percentile(lat, 50), percentile(lat, 95), percentile(lat, 99)
	return st
}

// percentile is the nearest-rank percentile of sorted.
func percentile(sorted []time.Duration, p int) time.Duration {
	if len(sorted) == 0 {
		return 0
	}
	i := (len(sorted)*p+99)/100 - 1
	return sorted[max(i, 0)]
}

func ms(d time.Duration) string {
	return fmt.Sprintf("%.1fms", float64(d.Microseconds())/1000)
}

func joinLines(lines []string) string {
	var b bytes.Buffer
	for i, l := range lines {
		if i > 0 {
			b.WriteString("\n  ")
		}
		b.WriteString(l)
	}
	return b.String()
}

// request is a body and its content type.
type request struct {
	body        []byte
	contentType string
}

func jsonReq(s string) request {
	return request{body: []byte(s), contentType: "application/json"}
}

// proofPNG is a small image the API accepts as a payment proof.
var proofPNG = func() []byte {
	img := image.NewNRGBA(image.Rect(0, 0, 64, 64))
	for i := range img.Pix {
		img.Pix[i] = 0xff
	}
	img.Set(10, 10, color.Black)
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		panic(err)
	}
	return buf.Bytes()
}()

func proofReq() request {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	part, err := w.CreateFormFile("file", "proof.png")
	if err == nil {
		_, err = part.Write(proofPNG)
	}
	if err == nil {
		err = w.Close()
	}
	if err != nil {
		panic(err) // writing to a bytes.Buffer cannot fail
	}
	return request{body: buf.Bytes(), contentType: w.FormDataContentType()}
}

type client struct {
	base string
	http *http.Client
}

// do sends one request as u, with a fresh Idempotency-Key on writes, and
// decodes data into out when out is set.
func (c *client) do(ctx context.Context, u *user, method, path string, r request, out any) (int, time.Duration, error) {
	req, err := http.NewRequestWithContext(ctx, method, c.base+path, bytes.NewReader(r.body))
	if err != nil {
		return 0, 0, err
	}
	req.Header.Set("Authorization", "Bearer "+u.token)
	if r.contentType != "" {
		req.Header.Set("Content-Type", r.contentType)
	}
	if method != http.MethodGet {
		req.Header.Set("Idempotency-Key", uuid.Must(uuid.NewV7()).String())
	}
	start := time.Now()
	resp, err := c.http.Do(req)
	if err != nil {
		return 0, time.Since(start), err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	latency := time.Since(start)
	if err != nil {
		return resp.StatusCode, latency, err
	}
	if out != nil && resp.StatusCode < 300 {
		var env struct {
			Data json.RawMessage `json:"data"`
		}
		if err := json.Unmarshal(raw, &env); err != nil {
			return resp.StatusCode, latency, fmt.Errorf("decode %s %s: %w", method, path, err)
		}
		if err := json.Unmarshal(env.Data, out); err != nil {
			return resp.StatusCode, latency, fmt.Errorf("decode %s %s: %w", method, path, err)
		}
	}
	if resp.StatusCode >= 400 && out != nil {
		return resp.StatusCode, latency, fmt.Errorf("%s %s: %d %s", method, path, resp.StatusCode, raw)
	}
	return resp.StatusCode, latency, nil
}

// must is do for setup steps, which have to return want.
func (c *client) must(ctx context.Context, u *user, method, path string, r request, want int, out any) error {
	if out == nil {
		out = &json.RawMessage{}
	}
	status, _, err := c.do(ctx, u, method, path, r, out)
	if err != nil {
		return err
	}
	if status != want {
		return fmt.Errorf("%s %s: status %d, want %d", method, path, status, want)
	}
	return nil
}
