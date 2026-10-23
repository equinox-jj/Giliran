package model

import "testing"

func TestPaymentStatusCanTransitionTo(t *testing.T) {
	// Arrange
	allowed := map[[2]PaymentStatus]bool{
		{PaymentStatusUnpaid, PaymentStatusPendingReview}:   true,
		{PaymentStatusUnpaid, PaymentStatusPaid}:            true,
		{PaymentStatusPendingReview, PaymentStatusPaid}:     true,
		{PaymentStatusPendingReview, PaymentStatusRejected}: true,
		{PaymentStatusRejected, PaymentStatusPendingReview}: true,
	}
	statuses := []PaymentStatus{PaymentStatusUnpaid, PaymentStatusPendingReview, PaymentStatusPaid, PaymentStatusRejected}

	for _, from := range statuses {
		for _, to := range statuses {
			want := allowed[[2]PaymentStatus{from, to}]

			t.Run(string(from)+"->"+string(to), func(t *testing.T) {
				// Act
				got := from.CanTransitionTo(to)

				// Assert
				if got != want {
					t.Errorf("got %v, want %v", got, want)
				}
			})
		}
	}
}

func TestPaymentEnumsIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value interface{ IsValid() bool }
		want  bool
	}{
		{"unpaid", PaymentStatusUnpaid, true},
		{"pending_review", PaymentStatusPendingReview, true},
		{"paid", PaymentStatusPaid, true},
		{"rejected", PaymentStatusRejected, true},
		{"refunded", PaymentStatus("refunded"), false},
		{"transfer", PaymentMethodTransfer, true},
		{"cash", PaymentMethodCash, true},
		{"other", PaymentMethodOther, true},
		{"card", PaymentMethod("card"), false},
		{"jpeg", ProofContentTypeJPEG, true},
		{"png", ProofContentTypePNG, true},
		{"webp", ProofContentTypeWebP, true},
		{"gif", ProofContentType("image/gif"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got := tt.value.IsValid()

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
