// Package routes maps URLs to controllers. Everything lives under /api/v1.
package routes

import (
	"github.com/gofiber/fiber/v3"

	"github.com/equinox-jj/Giliran/backend/internal/controller"
)

// Register adds every route to app.
func Register(app *fiber.App, health *controller.HealthController) {
	v1 := app.Group("/api/v1")
	v1.Get("/health", health.Get)
}
