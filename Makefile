.PHONY: up down restart logs shell status update docker-test token

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
	docker inspect --format='{{.Name}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' kirocrew 2>/dev/null || true

update:
	docker compose pull kirocrew
	docker compose up -d --force-recreate kirocrew

docker-test:
	docker compose exec kirocrew docker ps

token:
	docker compose exec kirocrew kirocrew token
