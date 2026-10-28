package email

import (
	"context"
	"errors"
	"fmt"
	stdmail "net/mail"
	"strings"
	"time"

	mail "github.com/wneessen/go-mail"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// smtpTimeout bounds connecting to the server and each command after it.
const smtpTimeout = 15 * time.Second

// maxProviderIDLen caps what is stored from the server's reply.
const maxProviderIDLen = 255

// SMTP sends through an SMTP server such as Resend's or, in development,
// Mailpit. Each Send opens its own connection, so it is safe for
// concurrent use.
type SMTP struct {
	client *mail.Client
	from   *stdmail.Address
}

// NewSMTP builds the client from SMTP_*. It does not contact the server.
func NewSMTP(cfg config.SMTP) (*SMTP, error) {
	if cfg.Host == "" {
		return nil, errors.New("email: SMTP_HOST is required by the worker")
	}
	from, err := stdmail.ParseAddress(cfg.From)
	if err != nil {
		return nil, fmt.Errorf("email: SMTP_FROM: %w", err)
	}
	opts := []mail.Option{mail.WithPort(cfg.Port), mail.WithTimeout(smtpTimeout)}
	switch cfg.TLS {
	case config.SMTPTLSImplicit:
		opts = append(opts, mail.WithSSL())
	case config.SMTPTLSNone:
		opts = append(opts, mail.WithTLSPolicy(mail.NoTLS))
	default:
		opts = append(opts, mail.WithTLSPolicy(mail.TLSMandatory))
	}
	if cfg.Username != "" {
		opts = append(opts, mail.WithSMTPAuth(mail.SMTPAuthAutoDiscover),
			mail.WithUsername(cfg.Username), mail.WithPassword(cfg.Password))
	}
	client, err := mail.NewClient(cfg.Host, opts...)
	if err != nil {
		return nil, fmt.Errorf("email: smtp client: %w", err)
	}
	return &SMTP{client: client, from: from}, nil
}

// Send delivers msg as multipart/alternative, plain text first. The
// provider ID is the server's reply to the message data (Resend puts its
// email ID there), or the Message-ID when the server says nothing useful.
// A 5xx reply is Permanent.
func (s *SMTP) Send(ctx context.Context, msg Message) (string, error) {
	m := mail.NewMsg(mail.WithNoDefaultUserAgent())
	m.FromMailAddress(s.from)
	if err := m.To(msg.To); err != nil {
		return "", Permanent(fmt.Errorf("email: recipient: %w", err))
	}
	m.Subject(msg.Subject)
	m.SetMessageID()
	m.SetDate()
	// Keeps auto-responders from answering a sign-in code (RFC 3834).
	m.SetGenHeader("Auto-Submitted", "auto-generated")
	m.SetBodyString(mail.TypeTextPlain, msg.Text)
	m.AddAlternativeString(mail.TypeTextHTML, msg.HTML)

	if err := s.client.DialAndSendWithContext(ctx, m); err != nil {
		var se *mail.SendError
		if errors.As(err, &se) && !se.IsTemp() && se.ErrorCode() >= 500 {
			return "", Permanent(err)
		}
		return "", err
	}
	id := strings.TrimSpace(m.ServerResponse())
	if id == "" {
		id = m.GetMessageID()
	}
	if len(id) > maxProviderIDLen {
		id = id[:maxProviderIDLen]
	}
	return id, nil
}
