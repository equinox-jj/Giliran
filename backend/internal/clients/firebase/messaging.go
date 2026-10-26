package firebase

import (
	"context"
	"fmt"

	fb "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
)

// Message is one push notification. Data travels with it for the app to
// route the tap.
type Message struct {
	Title string
	Body  string
	Data  map[string]string
}

// SendResult is what FCM did with one device token.
type SendResult struct {
	Token string
	Err   error // nil when delivered
	// Dead means the token will never work again, so it should be dropped.
	Dead bool
	// Transient means a later attempt may succeed.
	Transient bool
}

// Sender sends push notifications. The worker depends on this interface so
// tests can use a fake.
type Sender interface {
	// Send delivers msg to every token and reports each token's outcome in
	// order. An error means nothing was sent at all.
	Send(ctx context.Context, tokens []string, msg Message) ([]SendResult, error)
}

// Messenger is the FCM implementation of Sender.
type Messenger struct {
	client *messaging.Client
}

// NewMessenger builds the FCM client from app.
func NewMessenger(ctx context.Context, app *fb.App) (*Messenger, error) {
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase messaging client: %w", err)
	}
	return &Messenger{client: client}, nil
}

func (m *Messenger) Send(ctx context.Context, tokens []string, msg Message) ([]SendResult, error) {
	if len(tokens) == 0 {
		return nil, nil
	}
	res, err := m.client.SendEachForMulticast(ctx, &messaging.MulticastMessage{
		// The app registers FCM registration tokens (firebase_messaging's
		// getToken), which the v1 API takes as "token"; FIDs are a
		// different identifier.
		Tokens:       tokens, //nolint:staticcheck // see above
		Data:         msg.Data,
		Notification: &messaging.Notification{Title: msg.Title, Body: msg.Body},
		Android:      &messaging.AndroidConfig{Priority: "high"},
	})
	if err != nil {
		return nil, fmt.Errorf("send push: %w", err)
	}
	out := make([]SendResult, len(tokens))
	for i, token := range tokens {
		out[i] = SendResult{Token: token}
		if i >= len(res.Responses) || res.Responses[i] == nil {
			out[i].Err, out[i].Transient = fmt.Errorf("send push: no response for token"), true
			continue
		}
		if r := res.Responses[i]; !r.Success {
			out[i].Err = r.Error
			out[i].Dead, out[i].Transient = classify(r.Error)
		}
	}
	return out, nil
}

// classify sorts an FCM error for one token. Unregistered tokens and tokens
// of another sender are dead. Unavailable, internal and quota errors, and
// errors FCM gave no code for, such as a dropped connection, are
// transient. Anything else, such as an invalid argument, fails for good
// without dropping the token.
func classify(err error) (dead, transient bool) {
	switch {
	case messaging.IsUnregistered(err), messaging.IsSenderIDMismatch(err):
		return true, false
	case messaging.IsUnavailable(err), messaging.IsInternal(err), messaging.IsQuotaExceeded(err):
		return false, true
	case messaging.IsInvalidArgument(err), messaging.IsThirdPartyAuthError(err):
		return false, false
	}
	return false, true
}

var _ Sender = (*Messenger)(nil)
