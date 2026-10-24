package logger

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

func TestNewJSON(t *testing.T) {
	// Arrange
	var buf bytes.Buffer
	log := New(&buf, config.Log{Level: "info", Format: "json"}, config.App{Name: "giliran", Env: "staging"})

	// Act
	log.Info("hello", "k", "v")

	// Assert
	var line map[string]any
	if err := json.Unmarshal(buf.Bytes(), &line); err != nil {
		t.Fatalf("not JSON: %q", buf.String())
	}
	for k, want := range map[string]any{"msg": "hello", "k": "v", "app": "giliran", "env": "staging", "level": "INFO"} {
		if line[k] != want {
			t.Errorf("%s = %v, want %v", k, line[k], want)
		}
	}
}

func TestNewText(t *testing.T) {
	// Arrange
	var buf bytes.Buffer
	log := New(&buf, config.Log{Level: "debug", Format: "text"}, config.App{Name: "giliran", Env: "development"})

	// Act
	log.Debug("hello")

	// Assert
	if got := buf.String(); !strings.Contains(got, "level=DEBUG") || !strings.Contains(got, "msg=hello") {
		t.Errorf("got %q", got)
	}
}

func TestNewLevel(t *testing.T) {
	// Arrange
	tests := []struct {
		level   string
		logged  []string
		dropped []string
	}{
		{"debug", []string{"d", "i", "w", "e"}, nil},
		{"info", []string{"i", "w", "e"}, []string{"d"}},
		{"warn", []string{"w", "e"}, []string{"d", "i"}},
		{"error", []string{"e"}, []string{"d", "i", "w"}},
	}

	for _, tt := range tests {
		t.Run(tt.level, func(t *testing.T) {
			var buf bytes.Buffer
			log := New(&buf, config.Log{Level: tt.level, Format: "text"}, config.App{})

			// Act
			log.Debug("d")
			log.Info("i")
			log.Warn("w")
			log.Error("e")

			// Assert
			out := buf.String()
			for _, m := range tt.logged {
				if !strings.Contains(out, "msg="+m+" ") {
					t.Errorf("missing %q in %q", m, out)
				}
			}
			for _, m := range tt.dropped {
				if strings.Contains(out, "msg="+m+" ") {
					t.Errorf("unexpected %q in %q", m, out)
				}
			}
		})
	}
}
