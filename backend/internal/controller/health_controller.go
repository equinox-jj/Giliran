package controller

import (
	"github.com/gofiber/fiber/v3"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// HealthController serves GET /health.
type HealthController struct{}

func NewHealthController() *HealthController {
	return &HealthController{}
}

// Get reports that the API is up. The database ping (503
// service_unavailable when unreachable) arrives with the repository layer.
func (h *HealthController) Get(c fiber.Ctx) error {
	return response.OK(c, dto.HealthResponse{Status: "ok"})
}
