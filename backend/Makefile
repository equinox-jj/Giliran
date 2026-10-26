# Common tasks. `make help` lists them. Needs sqlc, golangci-lint and air on
# PATH (see CLAUDE.md); migrations run through the dev Compose stack.

COMPOSE := docker compose -f deploy/docker-compose.dev.yml

.DEFAULT_GOAL := help

.PHONY: help
help: ## List the targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: gen
gen: ## Generate internal/repository/sqlc from db/queries
	sqlc generate

.PHONY: gen-check
gen-check: ## Fail if the generated sqlc code is out of date
	sqlc diff

.PHONY: build
build: ## Build every package
	go build ./...

.PHONY: run
run: ## Run the API on the host (reads .env); start deps with `make deps-up`
	go run ./cmd/api

.PHONY: run-worker
run-worker: ## Run the worker on the host (reads .env); start deps with `make deps-up`
	go run ./cmd/worker

.PHONY: dev
dev: ## Run the API with live reload (Air)
	air

.PHONY: lint
lint: ## Run golangci-lint, including integration-tagged files
	golangci-lint run

.PHONY: fmt
fmt: ## Format code with the linters' formatters
	golangci-lint fmt

.PHONY: test
test: ## Unit tests (no Docker needed)
	go test ./...

.PHONY: test-integration
test-integration: ## Unit and integration tests (needs Docker)
	go test -tags integration -count=1 ./...

.PHONY: deps-up
deps-up: ## Start Postgres and MinIO, migrate (River too), create the bucket
	$(COMPOSE) up -d migrate river-migrate minio-init

.PHONY: up
up: ## Start the whole dev stack, API and worker included
	$(COMPOSE) up -d --build

.PHONY: down
down: ## Stop the dev stack (volumes are kept)
	$(COMPOSE) down

.PHONY: migrate-up
migrate-up: ## Apply all pending migrations
	$(COMPOSE) run --rm migrate up

.PHONY: migrate-down
migrate-down: ## Roll back one migration
	$(COMPOSE) run --rm migrate down 1

.PHONY: migrate-create
migrate-create: ## Create a migration pair: make migrate-create name=add_x
	@test -n "$(name)" || (echo "usage: make migrate-create name=<name>" && exit 1)
	$(COMPOSE) run --rm migrate create -ext sql -dir /migrations -seq $(name)
