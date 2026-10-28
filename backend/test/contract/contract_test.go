package contract

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// recorder is a testing.TB that collects Errorf calls instead of failing.
type recorder struct {
	testing.TB
	errs []string
}

func (r *recorder) Helper() {}

func (r *recorder) Errorf(format string, args ...any) {
	r.errs = append(r.errs, fmt.Sprintf(format, args...))
}

func jsonResponse(status int, contentType, body string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Header:     http.Header{"Content-Type": []string{contentType}},
		Body:       io.NopCloser(strings.NewReader(body)),
	}
}

func TestLoad(t *testing.T) {
	// Act
	spec := Load(t)

	// Assert
	if spec == nil {
		t.Fatal("Load returned nil")
	}
}

func TestAssertResponse(t *testing.T) {
	// Arrange
	spec := Load(t)
	tests := []struct {
		name     string
		path     string
		resp     *http.Response
		wantErrs bool
	}{
		{"valid health", "/api/v1/health", jsonResponse(200, "application/json", `{"data":{"status":"ok","checks":{"database":"ok"}}}`), false},
		{"wrong enum value", "/api/v1/health", jsonResponse(200, "application/json", `{"data":{"status":"fine","checks":{"database":"ok"}}}`), true},
		{"missing data", "/api/v1/health", jsonResponse(200, "application/json", `{}`), true},
		{"undocumented path", "/api/v1/nope", jsonResponse(200, "application/json", `{}`), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			rec := &recorder{TB: t}
			req := httptest.NewRequest(http.MethodGet, tt.path, nil)

			// Act
			spec.AssertResponse(rec, req, tt.resp)

			// Assert
			if got := len(rec.errs) > 0; got != tt.wantErrs {
				t.Errorf("got errors %v, want errors: %v", rec.errs, tt.wantErrs)
			}
		})
	}
}

func TestAssertResponseKeepsBodyReadable(t *testing.T) {
	// Arrange
	spec := Load(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	resp := jsonResponse(200, "application/json", `{"data":{"status":"ok","checks":{"database":"ok"}}}`)
	spec.AssertResponse(t, req, resp)

	// Act
	body, err := io.ReadAll(resp.Body)

	// Assert
	if err != nil || string(body) != `{"data":{"status":"ok","checks":{"database":"ok"}}}` {
		t.Errorf("body %q, err %v", body, err)
	}
}
