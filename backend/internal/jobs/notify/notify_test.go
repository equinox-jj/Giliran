package notify

import (
	"strings"
	"testing"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

func TestRenderEveryKind(t *testing.T) {
	// Arrange
	kinds := []Kind{
		KindProofUploaded, KindPaymentApproved, KindPaymentRejected, KindPaymentMarked,
		KindDrawCompleted, KindPayoutRecorded, KindPaymentReminder, KindMissedPayments,
	}
	p := Params{
		Group: "Arisan RT 05", PeriodNo: 3, Amount: 150_000, Member: "Budi", Reason: "Buram",
		Winner: "Sari", SlotNo: 2, DueDate: "2026-11-02", Count: 1, Names: []string{"Budi"},
	}
	for _, k := range kinds {
		for _, lang := range []model.Language{model.LanguageIndonesian, model.LanguageEnglish} {
			t.Run(string(k)+"/"+string(lang), func(t *testing.T) {
				// Act
				title, body, err := Render(k, lang, p)

				// Assert
				if err != nil || title == "" || body == "" {
					t.Fatalf("Render = %q, %q, %v", title, body, err)
				}
				if !strings.Contains(title+body, "Arisan RT 05") {
					t.Errorf("%q / %q does not name the group", title, body)
				}
			})
		}
	}
}

func TestRenderText(t *testing.T) {
	// Arrange
	tests := []struct {
		name      string
		kind      Kind
		lang      model.Language
		params    Params
		wantTitle string
		wantBody  string
	}{
		{
			"reminder in Indonesian", KindPaymentReminder, model.LanguageIndonesian,
			Params{Group: "Arisan RT 05", PeriodNo: 3, Amount: 150_000, DueDate: "2026-08-17"},
			"Pengingat iuran Arisan RT 05", "Iuran periode 3 sebesar Rp150.000 jatuh tempo 17 Agu 2026.",
		},
		{
			"unknown language falls back to Indonesian", KindPaymentApproved, "fr",
			Params{Group: "Arisan", PeriodNo: 1, Amount: 1_500_000},
			"Pembayaran diterima", "Pembayaran Rp1.500.000 untuk periode 1 di Arisan sudah disetujui.",
		},
		{
			"draw result in English", KindDrawCompleted, model.LanguageEnglish,
			Params{Group: "Arisan", PeriodNo: 2, Winner: "Sari D.", SlotNo: 4},
			"Arisan draw result", "Period 2 winner: Sari D. (slot 4).",
		},
		{
			"missing winner name", KindDrawCompleted, model.LanguageIndonesian,
			Params{Group: "Arisan", PeriodNo: 2, SlotNo: 4},
			"Hasil kocok Arisan", "Pemenang periode 2: Anggota (slot 4).",
		},
		{
			"missed payments beyond the names shown", KindMissedPayments, model.LanguageEnglish,
			Params{Group: "Arisan", PeriodNo: 5, Count: 4, Names: []string{"A", "B", "C"}},
			"Missed payments in Arisan", "4 past winners have not paid period 5: A, B, C, and 1 more.",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			title, body, err := Render(tt.kind, tt.lang, tt.params)

			// Assert
			if err != nil {
				t.Fatalf("Render: %v", err)
			}
			if title != tt.wantTitle || body != tt.wantBody {
				t.Errorf("got %q / %q\nwant %q / %q", title, body, tt.wantTitle, tt.wantBody)
			}
		})
	}
}

func TestRenderUnknownKind(t *testing.T) {
	// Act
	_, _, err := Render("nope", model.LanguageIndonesian, Params{})

	// Assert
	if err == nil {
		t.Error("got nil error for an unknown kind")
	}
}

func TestRupiah(t *testing.T) {
	// Arrange
	tests := []struct {
		amount int64
		want   string
	}{
		{0, "Rp0"},
		{999, "Rp999"},
		{1_000, "Rp1.000"},
		{150_000, "Rp150.000"},
		{100_000_000, "Rp100.000.000"},
		{-25_000, "-Rp25.000"},
	}
	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			// Act
			got := Rupiah(tt.amount)

			// Assert
			if got != tt.want {
				t.Errorf("Rupiah(%d) = %q, want %q", tt.amount, got, tt.want)
			}
		})
	}
}

func TestAllowed(t *testing.T) {
	// Arrange
	s := model.UserSettings{NotifyPaymentReminders: true, NotifyDrawResults: false, NotifyGroupActivity: true}
	tests := []struct {
		kind Kind
		want bool
	}{
		{KindPaymentReminder, true},
		{KindDrawCompleted, false},
		{KindPaymentApproved, true},
		{KindMissedPayments, true},
	}
	for _, tt := range tests {
		t.Run(string(tt.kind), func(t *testing.T) {
			// Act
			got := tt.kind.Allowed(s)

			// Assert
			if got != tt.want {
				t.Errorf("Allowed = %v, want %v", got, tt.want)
			}
		})
	}
}
