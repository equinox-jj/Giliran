package model

import "testing"

func TestLeaveRequestStatusCanTransitionTo(t *testing.T) {
	// Arrange
	allowed := map[[2]LeaveRequestStatus]bool{
		{LeaveRequestStatusPending, LeaveRequestStatusApproved}:  true,
		{LeaveRequestStatusPending, LeaveRequestStatusRejected}:  true,
		{LeaveRequestStatusPending, LeaveRequestStatusCancelled}: true,
	}
	statuses := []LeaveRequestStatus{
		LeaveRequestStatusPending, LeaveRequestStatusApproved,
		LeaveRequestStatusRejected, LeaveRequestStatusCancelled,
	}

	for _, from := range statuses {
		for _, to := range statuses {
			want := allowed[[2]LeaveRequestStatus{from, to}]

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

func TestLeaveRequestStatusIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value LeaveRequestStatus
		want  bool
	}{
		{"pending", LeaveRequestStatusPending, true},
		{"approved", LeaveRequestStatusApproved, true},
		{"rejected", LeaveRequestStatusRejected, true},
		{"cancelled", LeaveRequestStatusCancelled, true},
		{"withdrawn", LeaveRequestStatus("withdrawn"), false},
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
