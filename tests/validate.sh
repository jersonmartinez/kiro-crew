#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

docker compose --env-file .env.example config --quiet
docker compose --env-file .env.example --profile tools config --services | grep -F -- 'make' >/dev/null
python3 -m json.tool kirocrew-seccomp.json >/dev/null
python3 scripts/validation/validate-env.py .env.example
sh -n scripts/project/*.sh scripts/performance/*.sh scripts/runtime/*.sh tests/runtime/*.sh

test -f tests/runtime/smoke.sh

mask_test_dir=$(mktemp -d)
trap 'rm -rf "$mask_test_dir"' EXIT
mkdir -p "$mask_test_dir/projects/sample/node_modules"
PROJECTS_BASE="$mask_test_dir/projects" OUT="$mask_test_dir/override.yml" \
  sh scripts/performance/generate-mask-override.sh >/dev/null
test -f "$mask_test_dir/override.yml"
grep -F -- '/home/kirocrew/projects/sample/node_modules' "$mask_test_dir/override.yml" >/dev/null

test -f scripts/project/add-project.sh
test -f scripts/performance/generate-mask-override.sh
test -f scripts/validation/validate-env.py
test -f scripts/runtime/configure-instance.sh
test -f tests/validate.sh
test -f LICENSE
test -f AGENTS.md
test -f RTK.md
grep -F -- 'Prefer RTK' RTK.md >/dev/null

# Every file the agent instructions import must exist, and `make rtk-init` must
# still resolve to the documented project initialization command.
grep -F -- '@RTK.md' AGENTS.md >/dev/null
for ref in $(grep -o '^@[A-Za-z0-9._/-]\{1,\}' AGENTS.md); do
  ref=${ref#@}
  test -f "$ref" || { echo "AGENTS.md references missing file: $ref" >&2; exit 1; }
done
command -v make >/dev/null 2>&1 || { echo "make is required" >&2; exit 1; }
grep -E '^\.PHONY:.*[[:space:]]rtk-init([[:space:]]|$)' Makefile >/dev/null
make -n rtk-init | grep -F -- 'rtk init --codex' >/dev/null
test -f CODE_OF_CONDUCT.md
test -f CONTRIBUTING.md
test -f SECURITY.md
test -f docs/operations/budgets.md
test -f docs/assets/kirocrew-banner.svg
test -f docs/assets/kirocrew-architecture.svg
grep -F -- '<svg' docs/assets/kirocrew-banner.svg >/dev/null
grep -F -- '<svg' docs/assets/kirocrew-architecture.svg >/dev/null
python3 -c "import json, pathlib, xml.etree.ElementTree as ET; [json.loads(p.read_text()) for p in pathlib.Path('docs/architecture/source').glob('*.json')]; ET.parse('docs/assets/kirocrew-architecture.svg')"
test -f docs/en/decisions/ADR-013-openssh-client-for-gcp-iap.md
test -f docs/es/decisions/ADR-013-openssh-client-for-gcp-iap.md

grep -F -- '*-home-backup-*.tgz' .gitignore >/dev/null
grep -F -- 'google-cloud-cli' docker/Dockerfile.kirocrew >/dev/null
grep -F -- 'google-cloud-cli-gke-gcloud-auth-plugin' docker/Dockerfile.kirocrew >/dev/null
grep -F -- 'kubectl' docker/Dockerfile.kirocrew >/dev/null
grep -F -- 'openssh-client' docker/Dockerfile.kirocrew >/dev/null
grep -F -- 'kiro_crew/sandbox.py' docker/Dockerfile.kirocrew >/dev/null
grep -F -- 'Expected {expected} gcloud sandbox entries' docker/Dockerfile.kirocrew >/dev/null
grep -F -- 'KIROCREW_SOURCE_PROVIDER_TIMEOUT_SECS' docker/Dockerfile.kirocrew >/dev/null
grep -F -- 'KIROCREW_SOURCE_PROVIDER_TIMEOUT_SECS' compose/kiro-a.yml >/dev/null
grep -F -- 'KIROCREW_SOURCE_PROVIDER_TIMEOUT_SECS' compose/kiro-b.yml >/dev/null
grep -F -- 'compose/shared.yml' docker-compose.yml >/dev/null
grep -F -- 'CLOUDSDK_CONFIG: /home/kirocrew/.config/gcloud' compose/kiro-a.yml >/dev/null
grep -F -- 'CLOUDSDK_CONFIG: /home/kirocrew/.config/gcloud' compose/kiro-b.yml >/dev/null
grep -F -- 'agent.subagent_cwd_allowed_roots' scripts/runtime/configure-instance.sh >/dev/null
grep -F -- '/home/kirocrew/projects' scripts/runtime/configure-instance.sh >/dev/null
git diff --check

touch kiro-a-home-backup-validation.tgz
if ! git check-ignore -q kiro-a-home-backup-validation.tgz; then
  rm -f kiro-a-home-backup-validation.tgz
  echo "Backup archives must be ignored" >&2
  exit 1
fi
rm -f kiro-a-home-backup-validation.tgz

echo "validation-ok"
