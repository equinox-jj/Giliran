package controller

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"hash"
	"io"
	"maps"
	"slices"
	"strings"

	"github.com/gofiber/fiber/v3"

	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/security"
)

const (
	// HeaderIdempotencyKey carries the client's key for a retryable write.
	HeaderIdempotencyKey = "Idempotency-Key"
	// HeaderIdempotentReplayed marks a response replayed from a stored key.
	HeaderIdempotentReplayed = "Idempotent-Replayed"
)

// IdempotencyRunner is what Idempotency needs from
// service.IdempotencyService.
type IdempotencyRunner interface {
	Run(ctx context.Context, req service.IdempotentRequest, fn func(ctx context.Context) (service.StoredResponse, error)) (service.StoredResponse, bool, error)
}

// Idempotency is the middleware for payment, payout, draw and reminder
// writes (FR-PAY-06). It runs the rest of the chain inside the transaction
// that claims the key, so the stored response commits with the write; the
// services' own WithTx calls join it. A proof upload therefore holds its
// connection while the image goes to storage, which is fine at MVP scale.
type Idempotency struct {
	runner IdempotencyRunner
}

func NewIdempotency(runner *service.IdempotencyService) *Idempotency {
	return &Idempotency{runner: runner}
}

// Handle requires the Idempotency-Key header and runs the handler at most
// once per key. Place it after middleware.Auth.
func (h *Idempotency) Handle(c fiber.Ctx) error {
	key := c.Get(HeaderIdempotencyKey)
	if err := checkIdempotencyKey(key); err != nil {
		return err
	}
	reqHash, err := requestHash(c)
	if err != nil {
		return err
	}
	orig := c.Context()
	defer c.SetContext(orig)
	resp, replayed, err := h.runner.Run(orig, service.IdempotentRequest{
		UserID: middleware.UserID(c), Key: key, Method: c.Method(), Path: c.Path(), Hash: reqHash,
	}, func(ctx context.Context) (service.StoredResponse, error) {
		c.SetContext(ctx)
		if err := c.Next(); err != nil {
			return service.StoredResponse{}, err
		}
		return service.StoredResponse{Status: c.Response().StatusCode(), Body: bytes.Clone(c.Response().Body())}, nil
	})
	if err != nil {
		return err
	}
	if !replayed {
		return nil
	}
	c.Set(HeaderIdempotentReplayed, "true")
	c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
	return c.Status(resp.Status).Send(resp.Body)
}

func checkIdempotencyKey(key string) error {
	switch {
	case key == "":
		return model.NewValidationError(model.FieldError{
			Field: HeaderIdempotencyKey, Code: model.FieldRequired, Message: "This header is required.",
		})
	case len(key) < model.MinIdempotencyKeyLength:
		return model.NewValidationError(model.FieldError{
			Field: HeaderIdempotencyKey, Code: model.FieldMinLength,
			Message: fmt.Sprintf("Must have at least %d characters.", model.MinIdempotencyKeyLength),
		})
	case len(key) > model.MaxIdempotencyKeyLength:
		return model.NewValidationError(model.FieldError{
			Field: HeaderIdempotencyKey, Code: model.FieldMaxLength,
			Message: fmt.Sprintf("Must have at most %d characters.", model.MaxIdempotencyKeyLength),
		})
	}
	return nil
}

// requestHash fingerprints the request body. A multipart body is hashed by
// its fields and file contents, because its boundary changes on every
// retry; a form that does not parse falls back to the raw body and is left
// for the handler to reject.
func requestHash(c fiber.Ctx) (string, error) {
	if !strings.HasPrefix(string(c.Request().Header.ContentType()), fiber.MIMEMultipartForm) {
		return security.SHA256Hex(c.Body()), nil
	}
	form, err := c.MultipartForm()
	if err != nil {
		return security.SHA256Hex(c.Body()), nil
	}
	h := sha256.New()
	for _, name := range slices.Sorted(maps.Keys(form.Value)) {
		for _, v := range form.Value[name] {
			writeParts(h, "value", name, v)
		}
	}
	for _, name := range slices.Sorted(maps.Keys(form.File)) {
		for _, fh := range form.File[name] {
			f, err := fh.Open()
			if err != nil {
				return "", err
			}
			data, err := io.ReadAll(f)
			_ = f.Close()
			if err != nil {
				return "", err
			}
			writeParts(h, "file", name, string(data))
		}
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// writeParts writes each part with its length, so no two lists of parts
// hash alike.
func writeParts(h hash.Hash, parts ...string) {
	for _, p := range parts {
		_, _ = fmt.Fprintf(h, "%d:%s", len(p), p)
	}
}
