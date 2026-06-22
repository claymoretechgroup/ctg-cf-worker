# CTG CF Staging Environment — Makefile
#
# A local staging environment for Cloudflare Workers backed by D1 (SQLite).
# Mirrors the verbs of ctg-php-staging, wrapping `wrangler` instead of docker.
#
# Run `make help` to see all available targets.

.PHONY: dev init reset load-scenario dump query deploy db-create load-remote help

WRANGLER := npx wrangler
DB       := ctg_cf_staging        # must match database_name in wrangler.toml
SCENARIO ?= guitars               # default seed scenario (scenarios/<name>.d1.sql)
NAME     ?=

##@ Local Development

dev: ## Start the Worker locally with a local D1 (wrangler dev, foreground)
	$(WRANGLER) dev

init: ## Load the default scenario into the local D1 (SCENARIO=guitars)
	$(WRANGLER) d1 execute $(DB) --local --file=scenarios/$(SCENARIO).d1.sql

reset: ## Wipe local D1 state and re-seed (SCENARIO=name to pick the seed)
	rm -rf .wrangler/state
	$(WRANGLER) d1 execute $(DB) --local --file=scenarios/$(SCENARIO).d1.sql

##@ Scenarios

load-scenario: ## Load a scenario into the local D1 (NAME=my-scenario)
	@if [ -z "$(NAME)" ]; then echo "Usage: make load-scenario NAME=my-scenario"; exit 1; fi
	$(WRANGLER) d1 execute $(DB) --local --file=scenarios/$(NAME).d1.sql

dump: ## Export the local D1 to a scenario file (NAME=my-scenario)
	@if [ -z "$(NAME)" ]; then echo "Usage: make dump NAME=my-scenario"; exit 1; fi
	$(WRANGLER) d1 export $(DB) --local --output=scenarios/$(NAME).d1.sql

query: ## Run a SQL command against the local D1 (CMD="SELECT * FROM guitars")
	@if [ -z "$(CMD)" ]; then echo 'Usage: make query CMD="SELECT * FROM guitars"'; exit 1; fi
	$(WRANGLER) d1 execute $(DB) --local --command "$(CMD)"

##@ Remote (Cloudflare account required)

db-create: ## Create the remote D1 database (one-time; paste the id into wrangler.toml)
	$(WRANGLER) d1 create $(DB)

load-remote: ## Apply a scenario to the REMOTE D1 (NAME=my-scenario)
	@if [ -z "$(NAME)" ]; then echo "Usage: make load-remote NAME=my-scenario"; exit 1; fi
	$(WRANGLER) d1 execute $(DB) --remote --file=scenarios/$(NAME).d1.sql

deploy: ## Deploy the Worker to Cloudflare
	$(WRANGLER) deploy

##@ Help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
