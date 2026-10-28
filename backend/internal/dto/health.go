package dto

// HealthResponse is the data of GET /health.
type HealthResponse struct {
	Status string       `json:"status"`
	Checks HealthChecks `json:"checks"`
}

// HealthChecks reports each dependency GET /health checks.
type HealthChecks struct {
	Database string `json:"database"`
}
