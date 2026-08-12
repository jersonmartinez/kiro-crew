#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <project-name> [host-path]" >&2
  exit 1
fi

project_name="$1"
host_path="${2:-${PROJECTS_BASE:-$HOME/repos}/$project_name}"

if [[ ! "$project_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Project name may contain only letters, numbers, '.', '_' and '-'." >&2
  exit 1
fi

if [[ ! -d "$host_path" ]]; then
  echo "Host project directory does not exist: $host_path" >&2
  exit 1
fi

cat <<EOF
Add this entry under services.kirocrew.volumes in docker-compose.yml:

      - ${host_path}:/home/kirocrew/projects/${project_name}

Then recreate the service:
  docker compose up -d
EOF
