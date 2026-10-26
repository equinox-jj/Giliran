package main

import (
	"testing"

	"go.uber.org/fx"
)

func TestOptionsWiring(t *testing.T) {
	// Act
	err := fx.ValidateApp(options())

	// Assert
	if err != nil {
		t.Errorf("fx graph: %v", err)
	}
}
