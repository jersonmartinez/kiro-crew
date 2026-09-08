#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"

ENV_FILE=${COMPOSE_ENV_FILE:-.env}
if [ ! -f "$ENV_FILE" ]; then
  echo "Compose env file not found: $ENV_FILE" >&2
  exit 2
fi

python3 scripts/validation/validate-env.py "$ENV_FILE"

for service in kiro-a kiro-b; do
  container=$(docker compose --env-file "$ENV_FILE" ps -q "$service")
  [ -n "$container" ] || { echo "$service is not created" >&2; exit 1; }

  status=$(docker inspect --format '{{.State.Status}}' "$container")
  [ "$status" = running ] || { echo "$service status=$status" >&2; exit 1; }

  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container")
  [ "$health" = healthy ] || { echo "$service health=$health" >&2; exit 1; }
done

curl --fail --silent --show-error http://127.0.0.1:5476/health >/dev/null
curl --fail --silent --show-error http://127.0.0.1:5477/health >/dev/null

docker compose --env-file "$ENV_FILE" exec -T kiro-a sh -ec '
  command -v docker >/dev/null
  command -v node >/dev/null
  command -v gh >/dev/null
  command -v gcloud >/dev/null
  command -v ssh >/dev/null
  docker ps >/dev/null
  node --version >/dev/null
  gh --version >/dev/null
  gcloud compute ssh --help >/dev/null
  ssh -V 2>&1 >/dev/null
'

echo "runtime-smoke-ok"
