#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

docker compose --env-file .env.example config --quiet
docker compose --env-file .env.example --profile tools config --services | grep -F -- 'make' >/dev/null
python3 -m json.tool kirocrew-seccomp.json >/dev/null
sh -n scripts/*.sh

test -f scripts/add-project.sh
test -f scripts/generate-mask-override.sh
test -f tests/validate.sh
test -f LICENSE

grep -F -- '*-home-backup-*.tgz' .gitignore >/dev/null
grep -F -- 'google-cloud-cli' Dockerfile.kirocrew >/dev/null
grep -F -- 'google-cloud-sdk-gke-gcloud-auth-plugin' Dockerfile.kirocrew >/dev/null
grep -F -- 'kubectl' Dockerfile.kirocrew >/dev/null
grep -F -- 'compose/shared.yml' docker-compose.yml >/dev/null
grep -F -- 'CLOUDSDK_CONFIG: /home/kirocrew/.config/gcloud' compose/kiro-a.yml >/dev/null
grep -F -- 'CLOUDSDK_CONFIG: /home/kirocrew/.config/gcloud' compose/kiro-b.yml >/dev/null
git diff --check

touch kiro-a-home-backup-validation.tgz
if ! git check-ignore -q kiro-a-home-backup-validation.tgz; then
  rm -f kiro-a-home-backup-validation.tgz
  echo "Backup archives must be ignored" >&2
  exit 1
fi
rm -f kiro-a-home-backup-validation.tgz

echo "validation-ok"
