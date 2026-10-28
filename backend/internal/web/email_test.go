package web

import (
	"strings"
	"testing"
	"time"
)

func TestRenderOTP(t *testing.T) {
	// Arrange
	tests := []struct {
		name        string
		in          OTPEmail
		wantSubject string
		wantText    []string
	}{
		{
			"sign in, Indonesian",
			OTPEmail{Code: "482913", Purpose: OTPPurposeSignIn, ValidFor: 10 * time.Minute},
			"482913 adalah kode masuk Giliran",
			[]string{"Kode masuk Giliran kamu:", "482913", "Berlaku 10 menit."},
		},
		{
			"sign in, English",
			OTPEmail{Code: "482913", Purpose: OTPPurposeSignIn, ValidFor: 10 * time.Minute, English: true},
			"482913 is your Giliran sign-in code",
			[]string{"Your Giliran sign-in code:", "482913", "Valid for 10 minutes."},
		},
		{
			"reset PIN",
			OTPEmail{Code: "000417", Purpose: OTPPurposeResetPIN, ValidFor: 6*time.Minute + 10*time.Second},
			"000417 adalah kode reset PIN Giliran",
			[]string{"reset PIN", "000417", "Berlaku 7 menit."},
		},
		{
			"change email, English",
			OTPEmail{Code: "123456", Purpose: OTPPurposeChangeEmail, ValidFor: 9*time.Minute + 59*time.Second, English: true},
			"123456 is your Giliran email change code",
			[]string{"change your account email", "123456", "Valid for 10 minutes."},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := RenderOTP(tt.in)

			// Assert
			if err != nil {
				t.Fatalf("RenderOTP: %v", err)
			}
			if got.Subject != tt.wantSubject {
				t.Errorf("subject %q, want %q", got.Subject, tt.wantSubject)
			}
			for _, want := range tt.wantText {
				if !strings.Contains(got.Text, want) {
					t.Errorf("text lacks %q:\n%s", want, got.Text)
				}
			}
			if !strings.Contains(got.HTML, ">"+tt.in.Code+"<") {
				t.Errorf("html lacks the code:\n%s", got.HTML)
			}
			if strings.Contains(got.HTML, "http") || strings.Contains(got.Text, "http") {
				t.Error("a code email carries a link")
			}
		})
	}
}

func TestRenderOTPUnknownPurpose(t *testing.T) {
	// Act
	_, err := RenderOTP(OTPEmail{Code: "482913", Purpose: "nope", ValidFor: time.Minute})

	// Assert
	if err == nil {
		t.Error("got nil error")
	}
}

func TestRenderEmailChanged(t *testing.T) {
	// Arrange
	at := time.Date(2026, 10, 27, 7, 30, 0, 0, time.UTC) // 14:30 WIB
	tests := []struct {
		name     string
		in       EmailChangedEmail
		wantText []string
		wantHTML string
	}{
		{
			"Indonesian",
			EmailChangedEmail{NewEmailMasked: "ri•••••@gmail.com", ChangedAt: at},
			[]string{"diganti menjadi ri•••••@gmail.com pada 27 Oct 2026, 14:30 WIB"},
			"<strong>ri•••••@gmail.com</strong>",
		},
		{
			"English, account gone",
			EmailChangedEmail{ChangedAt: at, English: true},
			[]string{"was changed on 27 Oct 2026, 14:30 WIB"},
			"was changed on",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := RenderEmailChanged(tt.in)

			// Assert
			if err != nil {
				t.Fatalf("RenderEmailChanged: %v", err)
			}
			if got.Subject == "" {
				t.Error("empty subject")
			}
			for _, want := range tt.wantText {
				if !strings.Contains(got.Text, want) {
					t.Errorf("text lacks %q:\n%s", want, got.Text)
				}
			}
			if !strings.Contains(got.HTML, tt.wantHTML) {
				t.Errorf("html lacks %q:\n%s", tt.wantHTML, got.HTML)
			}
		})
	}
}

func TestRenderEmailChangedEscapesHTML(t *testing.T) {
	// Act
	got, err := RenderEmailChanged(EmailChangedEmail{NewEmailMasked: "<b>x</b>@y.id", ChangedAt: time.Now()})

	// Assert
	if err != nil {
		t.Fatalf("RenderEmailChanged: %v", err)
	}
	if strings.Contains(got.HTML, "<b>x</b>") {
		t.Errorf("html not escaped:\n%s", got.HTML)
	}
}
