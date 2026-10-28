package web

import (
	"bytes"
	"embed"
	"fmt"
	htmltemplate "html/template"
	texttemplate "text/template"
	"time"
)

//go:embed templates/email
var emailFiles embed.FS

var (
	emailHTML = htmltemplate.Must(htmltemplate.ParseFS(emailFiles, "templates/email/*.html"))
	emailText = texttemplate.Must(texttemplate.ParseFS(emailFiles, "templates/email/*.txt"))
)

// Email is a rendered email: its subject, HTML body and plain-text body.
type Email struct {
	Subject string
	HTML    string
	Text    string
}

// The purposes an OTP email can be for, as stored in
// email_otp_requests.purpose.
const (
	OTPPurposeSignIn      = "sign_in"
	OTPPurposeResetPIN    = "reset_pin"
	OTPPurposeChangeEmail = "change_email"
)

// OTPEmail is what otp.html and otp.txt show. Purpose picks the wording;
// English picks the language, Indonesian otherwise.
type OTPEmail struct {
	Code     string
	Purpose  string
	ValidFor time.Duration // what is left of the code's life
	English  bool
}

// Minutes is ValidFor rounded up to whole minutes, at least one, so a code
// sent the moment it was created reads "10 minutes", not 9.
func (e OTPEmail) Minutes() int {
	return max(int((e.ValidFor+time.Minute-1)/time.Minute), 1)
}

// RenderOTP renders a code email. The code leads the subject, so it shows
// in the notification (FR-AUTH-11).
func RenderOTP(e OTPEmail) (Email, error) {
	var subject string
	switch e.Purpose {
	case OTPPurposeSignIn:
		subject = pick(e.English, "%s adalah kode masuk Giliran", "%s is your Giliran sign-in code")
	case OTPPurposeResetPIN:
		subject = pick(e.English, "%s adalah kode reset PIN Giliran", "%s is your Giliran PIN reset code")
	case OTPPurposeChangeEmail:
		subject = pick(e.English, "%s adalah kode ganti email Giliran", "%s is your Giliran email change code")
	default:
		return Email{}, fmt.Errorf("otp email: unknown purpose %q", e.Purpose)
	}
	return render(fmt.Sprintf(subject, e.Code), "otp", e)
}

// EmailChangedEmail is what email_changed.html and email_changed.txt show,
// sent to the address an account moved away from.
type EmailChangedEmail struct {
	NewEmailMasked string // empty when the account is gone by send time
	ChangedAt      time.Time
	English        bool
}

// When is ChangedAt in Jakarta time.
func (e EmailChangedEmail) When() string {
	return e.ChangedAt.In(jakarta).Format("2 Jan 2006, 15:04 WIB")
}

// RenderEmailChanged renders the notice to the previous address.
func RenderEmailChanged(e EmailChangedEmail) (Email, error) {
	subject := pick(e.English, "Email akun Giliran kamu diganti", "Your Giliran account email was changed")
	return render(subject, "email_changed", e)
}

func render(subject, name string, data any) (Email, error) {
	var h, t bytes.Buffer
	if err := emailHTML.ExecuteTemplate(&h, name+".html", data); err != nil {
		return Email{}, fmt.Errorf("render %s.html: %w", name, err)
	}
	if err := emailText.ExecuteTemplate(&t, name+".txt", data); err != nil {
		return Email{}, fmt.Errorf("render %s.txt: %w", name, err)
	}
	return Email{Subject: subject, HTML: h.String(), Text: t.String()}, nil
}

func pick(english bool, id, en string) string {
	if english {
		return en
	}
	return id
}
