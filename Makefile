-include .env

PROJECT_PROFILE ?= dev

.PHONY: up up-a up-b configure down restart logs logs-a logs-b shell shell-a shell-b status update masks mask-report docker-test node-test gh-test gcloud-test kubectl-test kiro-login kiro-login-a kiro-login-b access-test token token-a token-b backup project-up project-down

INSTANCE ?= kiro-a

up: masks
	docker compose up -d --build --force-recreate kiro-a-config kiro-b-config kiro-a kiro-b

up-a: masks
	docker compose up -d --build --force-recreate kiro-a-config kiro-a

up-b: masks
	docker compose up -d --build --force-recreate kiro-b-config kiro-b

# Regenerate docker-compose.override.yml so dependency directories under
# PROJECTS_BASE are masked with empty tmpfs mounts (see ADR-009). Run this
# after cloning a repo or installing dependencies on the host.
masks:
	sh scripts/generate-mask-override.sh

# Report the traversal cost of a project tree as the container sees it.
# Usage: make mask-report PROJECT=example-org/sample-repo
mask-report:
ifndef PROJECT
	$(error PROJECT is required. Usage: make mask-report PROJECT=<relative-path>)
endif
	docker compose exec $(INSTANCE) python3 -c "import os,time,sys;b='/home/kirocrew/projects/'+sys.argv[1];t=time.time();n=sum(len(f) for _,_,f in os.walk(b));print('%s: %d files in %.1fs'%(sys.argv[1],n,time.time()-t))" $(PROJECT)

configure:
	docker compose up -d --force-recreate kiro-a-config kiro-b-config

down:
	docker compose down

restart: masks
	docker compose down
	docker compose up -d --build --force-recreate kiro-a-config kiro-b-config kiro-a kiro-b

logs:
	docker compose logs -f kiro-a kiro-b

logs-a:
	docker compose logs -f kiro-a

logs-b:
	docker compose logs -f kiro-b

shell:
	docker compose exec $(INSTANCE) bash

shell-a:
	docker compose exec kiro-a bash

shell-b:
	docker compose exec kiro-b bash

status:
	docker compose ps
	@docker inspect --format='{{.Name}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' kiro-a kiro-b 2>/dev/null || true

update: masks
	docker pull $(KIROCREW_IMAGE)
	docker compose build --pull kiro-a kiro-b
	docker compose up -d --force-recreate kiro-a-config kiro-b-config kiro-a kiro-b

docker-test:
	docker compose exec $(INSTANCE) docker ps

node-test:
	docker compose exec $(INSTANCE) node --version
	docker compose exec $(INSTANCE) npm --version
	docker compose exec $(INSTANCE) npx --version

gh-test:
	docker compose exec $(INSTANCE) gh --version
	docker compose exec $(INSTANCE) gh auth status
	docker compose exec $(INSTANCE) gh api user --jq .login
	docker compose exec $(INSTANCE) git config --global --get user.name
	docker compose exec $(INSTANCE) git config --global --get user.email

gcloud-test:
	docker compose exec $(INSTANCE) gcloud --version
	docker compose exec $(INSTANCE) gcloud auth list
	docker compose exec $(INSTANCE) gcloud config list

kubectl-test:
	docker compose exec $(INSTANCE) kubectl version --client
	docker compose exec $(INSTANCE) gke-gcloud-auth-plugin --version

# Confirm each instance is authenticated as its own GitHub account (ADR-010).
gh-identity:
	@for i in a b; do \
		printf 'kiro-%s: ' "$$i"; \
		docker compose exec -T "kiro-$$i" gh api user --jq .login 2>/dev/null || echo "NOT AUTHENTICATED"; \
	done

kiro-login: kiro-login-a

kiro-login-a:
	docker compose exec -it kiro-a kiro-cli login --use-device-flow

kiro-login-b:
	docker compose exec -it kiro-b kiro-cli login --use-device-flow

access-test:
	docker compose exec $(INSTANCE) bash -l -c 'id; test -w /home/kirocrew/.kiro; test -w /home/kirocrew/projects; docker ps >/dev/null; node --version; echo access-check-ok'

token: token-a

token-a:
	docker compose exec kiro-a kirocrew token

token-b:
	docker compose exec kiro-b kirocrew token

backup:
	@set -eu; \
	stamp=$$(date +%Y%m%d-%H%M%S); \
	trap 'docker compose up -d' EXIT; \
	echo "Stopping Kiro A and Kiro B for consistent backups..."; \
	docker compose down; \
	for instance in a b; do \
		container=kiro-$$instance-backup-$$stamp; \
		archive=kiro-$$instance-home-backup-$$stamp.tgz; \
		docker create --name "$$container" -v "kiro-$$instance-home:/source:ro" alpine tar czf "/tmp/$$archive" -C /source . >/dev/null; \
		docker start -a "$$container" >/dev/null; \
		docker cp "$$container:/tmp/$$archive" "$(CURDIR)/$$archive"; \
		docker rm "$$container" >/dev/null; \
		echo "Backup saved to $(CURDIR)/$$archive"; \
	done

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
	docker compose exec $(INSTANCE) sh -c 'cd /home/kirocrew/projects && docker compose -f "$(COMPOSE_PATH)" --profile "$(PROJECT_PROFILE)" up -d'

project-down:
ifndef NAME
	$(error NAME is required. Usage: make project-down NAME=demo-app)
endif
	@case "$(NAME)" in *[!A-Za-z0-9._-]*) echo "Invalid project name: $(NAME)" >&2; exit 2;; esac
	$(eval COMPOSE_PATH := $(or $($(shell echo $(NAME) | tr a-z A-Z)_COMPOSE),$(NAME)/infra/docker/compose.yml))
	docker compose exec $(INSTANCE) sh -c 'cd /home/kirocrew/projects && docker compose -f "$(COMPOSE_PATH)" --profile "$(PROJECT_PROFILE)" down'
