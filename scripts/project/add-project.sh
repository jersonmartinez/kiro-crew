#!/usr/bin/env sh
set -eu

name=${1:-}
project_path=${2:-${PROJECTS_BASE:-./projects}/${name}}

if [ -z "$name" ]; then
  echo "Usage: $0 <project-name> [project-path]" >&2
  exit 2
fi

case "$name" in
  *[!A-Za-z0-9._-]*)
    echo "Invalid project name: $name" >&2
    exit 2
    ;;
esac

if [ ! -d "$project_path" ]; then
  echo "Project directory does not exist: $project_path" >&2
  exit 1
fi

printf '%s\n' "      - ${project_path}:/home/kirocrew/projects/${name}"
