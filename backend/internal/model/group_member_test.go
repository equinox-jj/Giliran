package model

import "testing"

func TestMemberRoleCanManageGroup(t *testing.T) {
	// Arrange
	tests := []struct {
		role MemberRole
		want bool
	}{
		{MemberRoleOrganizer, true},
		{MemberRoleCoOrganizer, true},
		{MemberRoleMember, false},
	}

	for _, tt := range tests {
		t.Run(string(tt.role), func(t *testing.T) {
			// Act
			got := tt.role.CanManageGroup()

			// Assert
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestGroupMemberEnumsIsValid(t *testing.T) {
	// Arrange
	tests := []struct {
		name  string
		value interface{ IsValid() bool }
		want  bool
	}{
		{"organizer", MemberRoleOrganizer, true},
		{"co_organizer", MemberRoleCoOrganizer, true},
		{"member", MemberRoleMember, true},
		{"admin", MemberRole("admin"), false},
		{"active", MemberStatusActive, true},
		{"left", MemberStatusLeft, true},
		{"removed", MemberStatusRemoved, true},
		{"banned", MemberStatus("banned"), false},
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
