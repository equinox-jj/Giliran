package controller

import (
	"context"
	"fmt"
	"time"

	"github.com/gofiber/fiber/v3"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// healthPingTimeout bounds the database ping, so a stuck database fails the
// check instead of hanging the monitor.
const healthPingTimeout = 2 * time.Second

// Pinger is the database check behind GET /health; *pgxpool.Pool satisfies it.
type Pinger interface {
	Ping(ctx context.Context) error
}

// HealthController serves GET /health.
type HealthController struct {
	db Pinger
}

func NewHealthController(db Pinger) *HealthController {
	return &HealthController{db: db}
}

// Get reports that the API and its database are up. An unreachable database
// is 503 service_unavailable, which is what Uptime Kuma alerts on.
func (h *HealthController) Get(c fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(c.Context(), healthPingTimeout)
	defer cancel()
	if err := h.db.Ping(ctx); err != nil {
		// The cause is logged with the request; the client sees the sentinel.
		return fmt.Errorf("health: ping database: %w: %w", model.ErrServiceUnavailable, err)
	}
	return response.OK(c, dto.HealthResponse{Status: "ok", Checks: dto.HealthChecks{Database: "ok"}})
}
