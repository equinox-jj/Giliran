package response

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v3"
)

type item struct {
	ID string `json:"id"`
}

// newApp returns an app whose GET / runs h.
func newApp(h fiber.Handler) *fiber.App {
	app := fiber.New()
	app.Get("/", h)
	return app
}

// body sends GET / to app and returns the status, headers and raw body.
func body(t *testing.T, app *fiber.App) (*http.Response, string) {
	t.Helper()
	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/", nil))
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read body: %v", err)
	}
	return resp, string(b)
}

func TestOK(t *testing.T) {
	// Arrange
	app := newApp(func(c fiber.Ctx) error { return OK(c, item{ID: "g1"}) })

	// Act
	resp, got := body(t, app)

	// Assert
	if resp.StatusCode != 200 {
		t.Errorf("status %d, want 200", resp.StatusCode)
	}
	if got != `{"data":{"id":"g1"}}` {
		t.Errorf("body %s", got)
	}
}

func TestCreated(t *testing.T) {
	// Arrange
	app := newApp(func(c fiber.Ctx) error { return Created(c, "/api/v1/groups/g1", item{ID: "g1"}) })

	// Act
	resp, got := body(t, app)

	// Assert
	if resp.StatusCode != 201 {
		t.Errorf("status %d, want 201", resp.StatusCode)
	}
	if loc := resp.Header.Get("Location"); loc != "/api/v1/groups/g1" {
		t.Errorf("Location %q", loc)
	}
	if got != `{"data":{"id":"g1"}}` {
		t.Errorf("body %s", got)
	}
}

func TestNoContent(t *testing.T) {
	// Arrange
	app := newApp(func(c fiber.Ctx) error { return NoContent(c) })

	// Act
	resp, got := body(t, app)

	// Assert
	if resp.StatusCode != 204 {
		t.Errorf("status %d, want 204", resp.StatusCode)
	}
	if got != "" {
		t.Errorf("body %q, want empty", got)
	}
}

func TestList(t *testing.T) {
	// Arrange
	next := "42"
	tests := []struct {
		name  string
		items []item
		meta  any
		want  string
	}{
		{"nil slice", nil, nil, `{"data":[]}`},
		{"items without meta", []item{{ID: "a"}, {ID: "b"}}, nil, `{"data":[{"id":"a"},{"id":"b"}]}`},
		{"cursor meta", []item{{ID: "a"}}, CursorMeta{NextCursor: &next, HasMore: true}, `{"data":[{"id":"a"}],"meta":{"next_cursor":"42","has_more":true}}`},
		{"last page", []item{}, CursorMeta{}, `{"data":[],"meta":{"next_cursor":null,"has_more":false}}`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := newApp(func(c fiber.Ctx) error { return List(c, tt.items, tt.meta) })

			// Act
			resp, got := body(t, app)

			// Assert
			if resp.StatusCode != 200 {
				t.Errorf("status %d, want 200", resp.StatusCode)
			}
			if got != tt.want {
				t.Errorf("body %s, want %s", got, tt.want)
			}
		})
	}
}
