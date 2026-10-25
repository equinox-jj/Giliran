package repository

import (
	"context"
	"testing"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

func TestNewPoolRejectsBadURL(t *testing.T) {
	// Arrange
	cfg := config.Database{URL: "postgres://%zz", MaxConns: 1}

	// Act
	pool, err := NewPool(context.Background(), cfg)

	// Assert
	if err == nil {
		pool.Close()
		t.Fatal("NewPool: want an error for a malformed URL")
	}
}

func TestInTxWithoutTransaction(t *testing.T) {
	// Act
	got := InTx(context.Background())

	// Assert
	if got {
		t.Error("InTx(background) = true, want false")
	}
}
