-include .env

PROJECT_PROFILE ?= dev

.PHONY: up down restart logs shell status update docker-test node-test gh-test kiro-login access-test token backup project-up project-down

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

logs:
	docker compose logs -f kirocrew

shell:
	docker compose exec kirocrew bash

status:
	docker compose ps
	@docker inspect --format='{{.Name}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' kirocrew 2>/dev/null || true

update:
	docker compose pull kirocrew
	docker compose up -d --force-recreate kirocrew

docker-test:
	docker compose exec kirocrew docker ps

node-test:
	docker compose exec kirocrew node --version
	docker compose exec kirocrew npm --version
	docker compose exec kirocrew npx --version

gh-test:
	docker compose exec kirocrew gh --version
	docker compose exec kirocrew gh auth status

kiro-login:
	docker compose exec -it kirocrew kiro-cli login --use-device-flow

access-test:
	docker compose exec kirocrew bash -l -c 'id; test -w /home/kirocrew/.kiro; test -w /home/kirocrew/projects; docker ps >/dev/null; node --version; echo access-check-ok'

token:
	docker compose exec kirocrew kirocrew token

backup:
	@set -eu; \
	stamp=$$(date +%Y%m%d-%H%M%S); \
	container=kirocrew-backup-$$stamp; \
	archive=kirocrew-home-backup-$$stamp.tgz; \
	trap 'docker compose up -d; docker rm -f "$$container" >/dev/null 2>&1 || true' EXIT; \
	echo "Stopping KiroCrew for consistent backup..."; \
	docker compose down; \
	docker create --name "$$container" -v kirocrew-home:/source:ro alpine tar czf "/tmp/$$archive" -C /source . >/dev/null; \
	docker start -a "$$container" >/dev/null; \
	docker cp "$$container:/tmp/$$archive" "$(CURDIR)/$$archive"; \
	docker rm "$$container" >/dev/null; \
	echo "Backup saved to $(CURDIR)/$$archive. Restarting..."

# Usage: make project-up NAME=demo-app
# Starts a project's Docker stack using its internal compose file.
# The project may define DEMO_APP_COMPOSE (or <NAME>_COMPOSE) in .env,
# or defaults to <project>/infra/docker/compose.yml.
project-up:
ifndef NAME
	$(error NAME is required. Usage: make project-up NAME=demo-app)
endif
	@case "$(NAME)" in *[!A-Za-z0-9._-]*) echo "Invalid project name: $(NAME)" >&2; exit 2;; esac
	$(eval COMPOSE_PATH := $(or $($(shell echo $(NAME) | tr a-z A-Z)_COMPOSE),$(NAME)/infra/docker/compose.yml))
	docker compose exec kirocrew sh -c 'cd /home/kirocrew/projects && docker compose -f "$(COMPOSE_PATH)" --profile "$(PROJECT_PROFILE)" up -d'

project-down:
ifndef NAME
	$(error NAME is required. Usage: make project-down NAME=demo-app)
endif
	@case "$(NAME)" in *[!A-Za-z0-9._-]*) echo "Invalid project name: $(NAME)" >&2; exit 2;; esac
	$(eval COMPOSE_PATH := $(or $($(shell echo $(NAME) | tr a-z A-Z)_COMPOSE),$(NAME)/infra/docker/compose.yml))
	docker compose exec kirocrew sh -c 'cd /home/kirocrew/projects && docker compose -f "$(COMPOSE_PATH)" --profile "$(PROJECT_PROFILE)" down'
