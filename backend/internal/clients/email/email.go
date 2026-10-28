// Package email sends Giliran's transactional emails (sign-in codes and
// account notices) over SMTP. Only the worker sends mail, so only
// cmd/worker loads Module.
package email

import (
	"context"
	"errors"
)

// Message is one email with an HTML body and its plain-text alternative.
type Message struct {
	To      string
	Subject string
	HTML    string
	Text    string
}

// Sender delivers emails.
type Sender interface {
	// Send hands msg to the provider and returns the provider's reference
	// for it, for delivery troubleshooting. An error that IsPermanent will
	// fail the same way on a retry.
	Send(ctx context.Context, msg Message) (providerID string, err error)
}

// permanentError marks a failure the server will repeat, such as a
// rejected recipient (an SMTP 5xx reply).
type permanentError struct{ err error }

func (e permanentError) Error() string { return e.err.Error() }
func (e permanentError) Unwrap() error { return e.err }

// Permanent marks err as one a retry cannot fix.
func Permanent(err error) error {
	if err == nil {
		return nil
	}
	return permanentError{err: err}
}

// IsPermanent reports whether err, or an error it wraps, was marked
// Permanent. Everything else (timeouts, refused connections, 4xx replies)
// may pass, so a retry is worth it.
func IsPermanent(err error) bool {
	var p permanentError
	return errors.As(err, &p)
}
