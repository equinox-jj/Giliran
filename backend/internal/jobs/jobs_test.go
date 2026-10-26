package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/riverqueue/river"

	"github.com/equinox-jj/Giliran/backend/internal/jobs/notify"
)

func TestNewScheduleUsesLocation(t *testing.T) {
	// Arrange
	jakarta, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		t.Fatalf("LoadLocation: %v", err)
	}
	s, err := NewSchedule("0 8 * * *", jakarta)
	if err != nil {
		t.Fatalf("NewSchedule: %v", err)
	}
	from := time.Date(2026, time.October, 26, 2, 0, 0, 0, time.UTC) // 09:00 WIB

	// Act
	next := s.Next(from)

	// Assert
	if want := time.Date(2026, time.October, 27, 1, 0, 0, 0, time.UTC); !next.Equal(want) {
		t.Errorf("next run %s, want %s (08:00 WIB)", next.UTC(), want)
	}
}

func TestNewScheduleRejectsBadSpec(t *testing.T) {
	// Act
	_, err := NewSchedule("every morning", time.UTC)

	// Assert
	if err == nil {
		t.Error("got nil error")
	}
}

func TestPushAddsType(t *testing.T) {
	// Act
	p := Push([16]byte{1}, notify.KindDrawCompleted, notify.Params{Group: "G"}, map[string]string{"group_id": "g"})

	// Assert
	a, ok := p.Args.(PushArgs)
	if !ok {
		t.Fatalf("args %T", p.Args)
	}
	if a.Data["type"] != string(notify.KindDrawCompleted) || a.Data["group_id"] != "g" {
		t.Errorf("data %v", a.Data)
	}
	if opts := a.InsertOpts(); opts.Queue != QueuePush {
		t.Errorf("queue %q, want %q", opts.Queue, QueuePush)
	}
}

type recordingStore struct {
	deleted []string
	err     error
}

func (s *recordingStore) Delete(_ context.Context, key string) error {
	s.deleted = append(s.deleted, key)
	return s.err
}

type recordingDeleter struct {
	deleted []string
	err     error
}

func (d *recordingDeleter) DeleteUser(_ context.Context, uid string) error {
	d.deleted = append(d.deleted, uid)
	return d.err
}

func TestAccountPurgeWorker(t *testing.T) {
	// Arrange
	uid, key := "uid-budi", "avatars/budi.jpg"
	tests := []struct {
		name      string
		args      AccountPurgeArgs
		storeErr  error
		fbErr     error
		wantErr   bool
		wantKeys  int
		wantUsers int
	}{
		{"both", AccountPurgeArgs{FirebaseUID: &uid, AvatarKey: &key}, nil, nil, false, 1, 1},
		{"no avatar", AccountPurgeArgs{FirebaseUID: &uid}, nil, nil, false, 0, 1},
		{"firebase down retries", AccountPurgeArgs{FirebaseUID: &uid, AvatarKey: &key}, nil, errors.New("down"), true, 1, 1},
		{"storage down retries first", AccountPurgeArgs{FirebaseUID: &uid, AvatarKey: &key}, errors.New("down"), nil, true, 1, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			store := &recordingStore{err: tt.storeErr}
			fb := &recordingDeleter{err: tt.fbErr}
			w := &AccountPurgeWorker{store: store, firebase: fb}

			// Act
			err := w.Work(context.Background(), &river.Job[AccountPurgeArgs]{Args: tt.args})

			// Assert
			if (err != nil) != tt.wantErr {
				t.Errorf("err %v, want error %v", err, tt.wantErr)
			}
			if len(store.deleted) != tt.wantKeys || len(fb.deleted) != tt.wantUsers {
				t.Errorf("deleted keys %v, users %v", store.deleted, fb.deleted)
			}
		})
	}
}
