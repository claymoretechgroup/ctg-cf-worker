# CTG CF Staging Environment — Makefile
#
# A local staging environment for Cloudflare Workers backed by D1 (SQLite)
# and R2 (object storage). Mirrors the verbs of ctg-php-staging, wrapping
# `wrangler` instead of docker.
#
# Run `make help` to see all available targets.

.PHONY: dev init reset load-scenario dump query r2-seed \
        deploy db-create r2-create load-remote dump-remote help

WRANGLER := npx wrangler
DB       := ctg_cf_staging        # must match database_name in wrangler.toml
BUCKET   := ctg-cf-staging        # must match bucket_name in wrangler.toml (R2: hyphens, no underscores)
STATE    := .wrangler/state       # local binding data (D1/R2/...); shared by dev + CLI
SCENARIO ?= guitars               # default D1 seed scenario (scenarios/<name>.d1.sql)
NAME     ?=

# --local + a fixed --persist-to keeps `wrangler dev` and the CLI pointed at the
# SAME local store. R2 in particular needs this (workers-sdk #13034), or
# CLI-seeded objects won't be visible to the running Worker.
LOCAL := --local --persist-to $(STATE)

##@ Local Development

dev: ## Start the Worker locally with local D1 + R2 (foreground)
	$(WRANGLER) dev --persist-to $(STATE)

init: ## Seed the local D1 and R2 for a first run
	$(WRANGLER) d1 execute $(DB) $(LOCAL) --file=scenarios/$(SCENARIO).d1.sql
	@$(MAKE) r2-seed

reset: ## Wipe all local state and re-seed D1 + R2
	rm -rf $(STATE)
	@$(MAKE) init

##@ D1 scenarios

load-scenario: ## Load a scenario into the local D1 (NAME=my-scenario)
	@if [ -z "$(NAME)" ]; then echo "Usage: make load-scenario NAME=my-scenario"; exit 1; fi
	$(WRANGLER) d1 execute $(DB) $(LOCAL) --file=scenarios/$(NAME).d1.sql

dump: ## Export the local D1 to a scenario file (NAME=my-scenario)
	@if [ -z "$(NAME)" ]; then echo "Usage: make dump NAME=my-scenario"; exit 1; fi
	$(WRANGLER) d1 export $(DB) $(LOCAL) --output=scenarios/$(NAME).d1.sql

query: ## Run a SQL command against the local D1 (CMD="SELECT * FROM guitars")
	@if [ -z "$(CMD)" ]; then echo 'Usage: make query CMD="SELECT * FROM guitars"'; exit 1; fi
	$(WRANGLER) d1 execute $(DB) $(LOCAL) --command "$(CMD)"

##@ R2 fixtures

r2-seed: ## Seed the local R2 bucket from fixtures/r2/ (object key = path under fixtures/r2/)
	@if [ ! -d fixtures/r2 ]; then echo "r2-seed: no fixtures/r2/ directory — skipping"; exit 0; fi
	@find fixtures/r2 -type f | while read -r f; do \
		key="$${f#fixtures/r2/}"; \
		echo "r2 put $$key"; \
		$(WRANGLER) r2 object put "$(BUCKET)/$$key" $(LOCAL) --file="$$f"; \
	done

##@ Remote (Cloudflare account required)

db-create: ## Create the remote D1 database (one-time; paste the id into wrangler.toml)
	$(WRANGLER) d1 create $(DB)

r2-create: ## Create the remote R2 bucket (one-time)
	$(WRANGLER) r2 bucket create $(BUCKET)

load-remote: ## Import a scenario into the REMOTE D1 (NAME=my-scenario)
	@if [ -z "$(NAME)" ]; then echo "Usage: make load-remote NAME=my-scenario"; exit 1; fi
	$(WRANGLER) d1 execute $(DB) --remote --file=scenarios/$(NAME).d1.sql

dump-remote: ## Export the REMOTE D1 to a scenario file (NAME=my-scenario)
	@if [ -z "$(NAME)" ]; then echo "Usage: make dump-remote NAME=my-scenario"; exit 1; fi
	$(WRANGLER) d1 export $(DB) --remote --output=scenarios/$(NAME).d1.sql

deploy: ## Deploy the Worker to Cloudflare
	$(WRANGLER) deploy

##@ Help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
