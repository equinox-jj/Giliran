package dto

// HealthResponse is the data of GET /health.
type HealthResponse struct {
	Status string `json:"status"`
}
