// Package contract checks HTTP responses against api/api-spec.yaml, so a
// handler that drifts from the OpenAPI spec fails its test. It needs no
// Docker: unit tests driving a *fiber.App with app.Test can use it, and so
// can integration tests.
package contract

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"testing"

	"github.com/pb33f/libopenapi"
	validator "github.com/pb33f/libopenapi-validator"
)

// Spec validates responses against the parsed OpenAPI document.
type Spec struct {
	v validator.Validator
}

var (
	loadOnce sync.Once
	loaded   *Spec
	loadErr  error
)

// Load parses api/api-spec.yaml once per test binary and fails t if the
// spec cannot be read or is not a valid OpenAPI document.
func Load(t testing.TB) *Spec {
	t.Helper()
	loadOnce.Do(func() { loaded, loadErr = load() })
	if loadErr != nil {
		t.Fatalf("contract: %v", loadErr)
	}
	return loaded
}

func load() (*Spec, error) {
	_, file, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(file), "..", "..", "api", "api-spec.yaml")
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read spec: %w", err)
	}
	doc, err := libopenapi.NewDocument(raw)
	if err != nil {
		return nil, fmt.Errorf("parse spec: %w", err)
	}
	v, errs := validator.NewValidator(doc)
	if len(errs) > 0 {
		return nil, fmt.Errorf("build validator: %v", errs)
	}
	if ok, verrs := v.ValidateDocument(); !ok {
		return nil, fmt.Errorf("spec is not valid OpenAPI: %v", verrs)
	}
	return &Spec{v: v}, nil
}

// AssertResponse reports, through t.Errorf, every way resp differs from what
// the spec documents for req's operation and resp's status: an undocumented
// path or status, the wrong content type, or a body that breaks the schema.
// req.URL.Path must include the /api/v1 base path. resp.Body stays readable.
func (s *Spec) AssertResponse(t testing.TB, req *http.Request, resp *http.Response) {
	t.Helper()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("contract: read body: %v", err)
	}
	_ = resp.Body.Close()
	resp.Body = io.NopCloser(bytes.NewReader(body))

	ok, errs := s.v.ValidateHttpResponse(req, resp)
	resp.Body = io.NopCloser(bytes.NewReader(body))
	if ok {
		return
	}
	for _, e := range errs {
		t.Errorf("contract: %s %s → %d: %s", req.Method, req.URL.Path, resp.StatusCode, e.Error())
	}
}
