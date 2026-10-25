// Package integration holds helpers for tests that need real services. Tests
// that use them carry the `integration` build tag, so `go test ./...` runs
// without Docker and `make test-integration` runs everything.
package integration

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

// postgresImage matches deploy/docker-compose.dev.yml.
const postgresImage = "postgres:18.6-alpine3.24"

const templateDB = "giliran_template"

var (
	setupOnce sync.Once
	setupErr  error
	adminURL  *url.URL // the container's default database

	createMu sync.Mutex // CREATE DATABASE … TEMPLATE fails if run concurrently
	dbSeq    atomic.Int64
)

// NewDB returns a pool on a new database with every migration applied. The
// database is dropped when t ends.
//
// The first call starts one Postgres container for the test binary and
// migrates a template database; every call clones that template, which takes
// milliseconds, so tests get a clean state and can run in parallel.
// Testcontainers' reaper removes the container when the binary exits.
func NewDB(t testing.TB) *pgxpool.Pool {
	t.Helper()
	setupOnce.Do(func() { setupErr = setup() })
	if setupErr != nil {
		t.Fatalf("integration: postgres setup: %v", setupErr)
	}

	ctx := context.Background()
	name := fmt.Sprintf("test_%d_%d", os.Getpid(), dbSeq.Add(1))
	createMu.Lock()
	err := adminExec(ctx, fmt.Sprintf("CREATE DATABASE %s TEMPLATE %s", name, templateDB))
	createMu.Unlock()
	if err != nil {
		t.Fatalf("integration: create database: %v", err)
	}

	pool, err := pgxpool.New(ctx, dbURL(name))
	if err != nil {
		t.Fatalf("integration: connect: %v", err)
	}
	t.Cleanup(func() {
		pool.Close()
		if err := adminExec(context.Background(), fmt.Sprintf("DROP DATABASE %s WITH (FORCE)", name)); err != nil {
			t.Logf("integration: drop database %s: %v", name, err)
		}
	})
	return pool
}

func setup() error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	ctr, err := postgres.Run(ctx, postgresImage,
		postgres.WithDatabase("giliran"),
		postgres.WithUsername("giliran"),
		postgres.WithPassword("giliran"),
		postgres.BasicWaitStrategies(),
	)
	if err != nil {
		return err
	}
	dsn, err := ctr.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		return err
	}
	if adminURL, err = url.Parse(dsn); err != nil {
		return err
	}

	if err := adminExec(ctx, "CREATE DATABASE "+templateDB); err != nil {
		return err
	}
	conn, err := pgx.Connect(ctx, dbURL(templateDB))
	if err != nil {
		return err
	}
	// Clones need the template to have no open connections.
	defer conn.Close(ctx)
	return migrate(ctx, conn)
}

// migrate applies the up migrations in order, as golang-migrate would.
func migrate(ctx context.Context, conn *pgx.Conn) error {
	_, file, _, _ := runtime.Caller(0)
	dir := filepath.Join(filepath.Dir(file), "..", "..", "db", "migrations")
	files, err := filepath.Glob(filepath.Join(dir, "*.up.sql"))
	if err != nil {
		return err
	}
	if len(files) == 0 {
		return fmt.Errorf("no migrations in %s", dir)
	}
	sort.Strings(files)
	for _, f := range files {
		sql, err := os.ReadFile(f) //nolint:gosec // f is a migration file in this repo
		if err != nil {
			return err
		}
		// No arguments, so pgx uses the simple protocol and runs every
		// statement in the file.
		if _, err := conn.Exec(ctx, string(sql)); err != nil {
			return fmt.Errorf("%s: %w", filepath.Base(f), err)
		}
	}
	return nil
}

func adminExec(ctx context.Context, sql string) error {
	conn, err := pgx.Connect(ctx, adminURL.String())
	if err != nil {
		return err
	}
	defer conn.Close(ctx)
	_, err = conn.Exec(ctx, sql)
	return err
}

func dbURL(name string) string {
	u := *adminURL
	u.Path = "/" + name
	return u.String()
}
