// Package notify defines the push notifications Giliran sends and renders
// their text in the recipient's language. The worker renders at send time,
// so a language change applies to pushes already queued.
package notify

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// Kind is what a push is about. Each kind is governed by one notification
// setting (FR-PROF-03).
type Kind string

const (
	KindProofUploaded   Kind = "payment.proof_uploaded"
	KindPaymentApproved Kind = "payment.approved"
	KindPaymentRejected Kind = "payment.rejected"
	KindPaymentMarked   Kind = "payment.marked_paid"
	KindDrawCompleted   Kind = "draw.completed"
	KindPayoutRecorded  Kind = "payout.recorded"
	KindPaymentReminder Kind = "payment.reminder"
	KindMissedPayments  Kind = "obligations.missed"
)

// Allowed reports whether s lets the user receive pushes of kind k.
func (k Kind) Allowed(s model.UserSettings) bool {
	switch k {
	case KindPaymentReminder:
		return s.NotifyPaymentReminders
	case KindDrawCompleted:
		return s.NotifyDrawResults
	}
	return s.NotifyGroupActivity
}

// Params fill a notification's text. Each kind reads the fields it needs.
type Params struct {
	Group    string   `json:"group"`
	PeriodNo int16    `json:"period_no,omitempty"`
	Amount   int64    `json:"amount,omitempty"` // rupiah
	Member   string   `json:"member,omitempty"`
	Reason   string   `json:"reason,omitempty"`
	Winner   string   `json:"winner,omitempty"`
	SlotNo   int16    `json:"slot_no,omitempty"`
	DueDate  string   `json:"due_date,omitempty"` // YYYY-MM-DD
	Count    int      `json:"count,omitempty"`
	Names    []string `json:"names,omitempty"`
}

// Render returns the title and body of a kind push in lang. Languages other
// than English get Indonesian, the default.
func Render(kind Kind, lang model.Language, p Params) (title, body string, err error) {
	en := lang == model.LanguageEnglish
	pick := func(id, eng string) string {
		if en {
			return eng
		}
		return id
	}
	if p.Member == "" {
		p.Member = pick("Seorang anggota", "A member")
	}
	if p.Winner == "" {
		p.Winner = pick("Anggota", "A member")
	}
	switch kind {
	case KindProofUploaded:
		return pick("Bukti bayar baru", "New payment proof"),
			pick(fmt.Sprintf("%s mengunggah bukti bayar periode %d di %s. Cek dan setujui.", p.Member, p.PeriodNo, p.Group),
				fmt.Sprintf("%s uploaded a payment proof for period %d in %s. Review it.", p.Member, p.PeriodNo, p.Group)), nil
	case KindPaymentApproved:
		return pick("Pembayaran diterima", "Payment approved"),
			pick(fmt.Sprintf("Pembayaran %s untuk periode %d di %s sudah disetujui.", Rupiah(p.Amount), p.PeriodNo, p.Group),
				fmt.Sprintf("Your %s payment for period %d in %s was approved.", Rupiah(p.Amount), p.PeriodNo, p.Group)), nil
	case KindPaymentRejected:
		return pick("Bukti bayar ditolak", "Payment proof rejected"),
			pick(fmt.Sprintf("Bukti bayar periode %d di %s ditolak: %s. Unggah bukti baru.", p.PeriodNo, p.Group, p.Reason),
				fmt.Sprintf("Your proof for period %d in %s was rejected: %s. Upload a new one.", p.PeriodNo, p.Group, p.Reason)), nil
	case KindPaymentMarked:
		return pick("Pembayaran dicatat lunas", "Payment marked paid"),
			pick(fmt.Sprintf("Pembayaran %s untuk periode %d di %s dicatat lunas oleh pengelola.", Rupiah(p.Amount), p.PeriodNo, p.Group),
				fmt.Sprintf("Your %s payment for period %d in %s was marked paid by the organizer.", Rupiah(p.Amount), p.PeriodNo, p.Group)), nil
	case KindDrawCompleted:
		return pick(fmt.Sprintf("Hasil kocok %s", p.Group), fmt.Sprintf("%s draw result", p.Group)),
			pick(fmt.Sprintf("Pemenang periode %d: %s (slot %d).", p.PeriodNo, p.Winner, p.SlotNo),
				fmt.Sprintf("Period %d winner: %s (slot %d).", p.PeriodNo, p.Winner, p.SlotNo)), nil
	case KindPayoutRecorded:
		return pick("Dana arisan dikirim", "Payout sent"),
			pick(fmt.Sprintf("Pengelola %s mencatat pencairan %s untuk periode %d. Konfirmasi setelah dana diterima.", p.Group, Rupiah(p.Amount), p.PeriodNo),
				fmt.Sprintf("The organizer of %s recorded your %s payout for period %d. Confirm once you receive it.", p.Group, Rupiah(p.Amount), p.PeriodNo)), nil
	case KindPaymentReminder:
		due := Date(p.DueDate, lang)
		return pick(fmt.Sprintf("Pengingat iuran %s", p.Group), fmt.Sprintf("%s payment reminder", p.Group)),
			pick(fmt.Sprintf("Iuran periode %d sebesar %s jatuh tempo %s.", p.PeriodNo, Rupiah(p.Amount), due),
				fmt.Sprintf("Your period %d payment of %s is due %s.", p.PeriodNo, Rupiah(p.Amount), due)), nil
	case KindMissedPayments:
		names := strings.Join(p.Names, ", ")
		if p.Count > len(p.Names) {
			names += pick(fmt.Sprintf(", dan %d lainnya", p.Count-len(p.Names)), fmt.Sprintf(", and %d more", p.Count-len(p.Names)))
		}
		return pick(fmt.Sprintf("Tunggakan di %s", p.Group), fmt.Sprintf("Missed payments in %s", p.Group)),
			pick(fmt.Sprintf("%d pemenang sebelumnya belum bayar periode %d: %s.", p.Count, p.PeriodNo, names),
				fmt.Sprintf("%d past winners have not paid period %d: %s.", p.Count, p.PeriodNo, names)), nil
	}
	return "", "", fmt.Errorf("notify: unknown kind %q", kind)
}

// Rupiah formats an amount the Indonesian way: 150000 is "Rp150.000".
func Rupiah(amount int64) string {
	sign := ""
	if amount < 0 {
		sign, amount = "-", -amount
	}
	digits := strconv.FormatInt(amount, 10)
	var b strings.Builder
	for i, d := range digits {
		if i > 0 && (len(digits)-i)%3 == 0 {
			b.WriteByte('.')
		}
		b.WriteRune(d)
	}
	return sign + "Rp" + b.String()
}

var idMonths = [...]string{"Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"}

// Date formats a YYYY-MM-DD business date as "2 Nov 2026", with
// Indonesian month names unless lang is English. Anything unparsable is
// returned unchanged.
func Date(s string, lang model.Language) string {
	d, err := time.Parse(time.DateOnly, s)
	if err != nil {
		return s
	}
	if lang == model.LanguageEnglish {
		return d.Format("2 Jan 2006")
	}
	return fmt.Sprintf("%d %s %d", d.Day(), idMonths[d.Month()-1], d.Year())
}
