package email

import (
	"bufio"
	"context"
	"net"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// smtpServer is just enough of an SMTP server for one client session at a
// time: it answers RCPT TO with rcptReply and the end of DATA with
// dataReply, and keeps the last message's data.
type smtpServer struct {
	addr      string
	rcptReply string
	dataReply string

	mu   sync.Mutex
	data string
}

func newSMTPServer(t *testing.T, rcptReply, dataReply string) *smtpServer {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	t.Cleanup(func() { _ = ln.Close() })
	s := &smtpServer{addr: ln.Addr().String(), rcptReply: rcptReply, dataReply: dataReply}
	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			go s.serve(conn)
		}
	}()
	return s
}

func (s *smtpServer) serve(conn net.Conn) {
	defer func() { _ = conn.Close() }()
	r := bufio.NewReader(conn)
	reply := func(line string) { _, _ = conn.Write([]byte(line + "\r\n")) }
	reply("220 test ESMTP")
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		cmd := strings.ToUpper(strings.TrimSpace(line))
		switch {
		case strings.HasPrefix(cmd, "EHLO"):
			reply("250-test")
			reply("250 8BITMIME")
		case strings.HasPrefix(cmd, "RCPT"):
			reply(s.rcptReply)
		case cmd == "DATA":
			reply("354 go ahead")
			var b strings.Builder
			for {
				l, err := r.ReadString('\n')
				if err != nil {
					return
				}
				if l == ".\r\n" {
					break
				}
				b.WriteString(l)
			}
			s.mu.Lock()
			s.data = b.String()
			s.mu.Unlock()
			reply(s.dataReply)
		case cmd == "QUIT":
			reply("221 bye")
			return
		default: // MAIL, RSET, NOOP
			reply("250 OK")
		}
	}
}

func (s *smtpServer) lastData() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.data
}

func newTestSMTP(t *testing.T, addr string) *SMTP {
	t.Helper()
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		t.Fatalf("split %s: %v", addr, err)
	}
	p, _ := strconv.Atoi(port)
	s, err := NewSMTP(config.SMTP{
		Host: host, Port: p, TLS: config.SMTPTLSNone, From: "Giliran <masuk@giliran.monai.my.id>",
	})
	if err != nil {
		t.Fatalf("NewSMTP: %v", err)
	}
	return s
}

var testMessage = Message{
	To:      "rina@gmail.com",
	Subject: "482913 adalah kode masuk Giliran",
	HTML:    "<p>482913</p>",
	Text:    "482913",
}

func TestSMTPSend(t *testing.T) {
	// Arrange
	srv := newSMTPServer(t, "250 OK", "250 OK queued as abc-123")
	s := newTestSMTP(t, srv.addr)

	// Act
	id, err := s.Send(context.Background(), testMessage)

	// Assert
	if err != nil {
		t.Fatalf("Send: %v", err)
	}
	if id != "OK queued as abc-123" {
		t.Errorf("provider id %q", id)
	}
	data := srv.lastData()
	for _, want := range []string{
		"From: \"Giliran\" <masuk@giliran.monai.my.id>",
		"To: <rina@gmail.com>",
		"Subject: 482913 adalah kode masuk Giliran",
		"Auto-Submitted: auto-generated",
		"multipart/alternative",
		"Content-Type: text/plain",
		"Content-Type: text/html",
	} {
		if !strings.Contains(data, want) {
			t.Errorf("message lacks %q:\n%s", want, data)
		}
	}
	if strings.Index(data, "text/plain") > strings.Index(data, "text/html") {
		t.Error("plain text must come before HTML, the preferred part last")
	}
}

func TestSMTPSendClassifiesFailures(t *testing.T) {
	// Arrange
	tests := []struct {
		name          string
		rcptReply     string
		wantPermanent bool
	}{
		{"mailbox unknown", "550 5.1.1 no such user", true},
		{"try later", "451 4.7.1 try again later", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			srv := newSMTPServer(t, tt.rcptReply, "250 OK")
			s := newTestSMTP(t, srv.addr)

			// Act
			_, err := s.Send(context.Background(), testMessage)

			// Assert
			if err == nil {
				t.Fatal("got nil error")
			}
			if got := IsPermanent(err); got != tt.wantPermanent {
				t.Errorf("IsPermanent %v, want %v (%v)", got, tt.wantPermanent, err)
			}
		})
	}
}

func TestSMTPSendServerDownIsTemporary(t *testing.T) {
	// Arrange
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	addr := ln.Addr().String()
	_ = ln.Close()
	s := newTestSMTP(t, addr)

	// Act
	_, err = s.Send(context.Background(), testMessage)

	// Assert
	if err == nil || IsPermanent(err) {
		t.Errorf("err %v, want a temporary error", err)
	}
}

func TestNewSMTPNeedsHost(t *testing.T) {
	// Act
	_, err := NewSMTP(config.SMTP{Port: 587, TLS: config.SMTPTLSStartTLS, From: "masuk@giliran.monai.my.id"})

	// Assert
	if err == nil {
		t.Error("got nil error")
	}
}
