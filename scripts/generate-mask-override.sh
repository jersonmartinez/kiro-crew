#!/usr/bin/env sh
# Generate a Compose override that masks dependency/cache directories inside
# the mounted projects tree.
#
# Why: PROJECTS_BASE is a Windows bind mount (Docker Desktop / virtiofs).
# Directory traversal there costs ~1ms per entry, so a repo carrying a large
# node_modules turns any project-tree walk into a multi-minute operation and
# starves the gateway's event loop — surfacing as
# `Request initialize timed out after <budget>s`.
#
# Masking each dependency directory with an empty tmpfs removes it from the
# container's view entirely: the walk no longer descends into it, and no host
# I/O is involved. Source files, .git and build output stay visible.
#
# The masks are container-side only (no host paths), so the generated file is
# portable across hosts even though the scan is host-specific.
set -eu

PROJECTS_MOUNT="${PROJECTS_MOUNT:-/workspace/projects}"
CONTAINER_PROJECTS="${CONTAINER_PROJECTS:-/home/kirocrew/projects}"
OUT="${OUT:-/workspace/docker-compose.override.yml}"
MASK_DIRS="${KIROCREW_MASK_DIRS:-node_modules .venv venv vendor target __pycache__ .next .nuxt .docusaurus .cache .pytest_cache .mypy_cache .gradle}"
MAX_DEPTH="${KIROCREW_MASK_MAX_DEPTH:-4}"
MASK_SIZE="${KIROCREW_MASK_TMPFS_SIZE:-1g}"
SERVICES="${KIROCREW_MASK_SERVICES:-kiro-a kiro-b}"

if [ ! -d "$PROJECTS_MOUNT" ]; then
  echo "Projects mount not found: $PROJECTS_MOUNT" >&2
  exit 1
fi

# Build the -name predicates for find.
set --
for d in $MASK_DIRS; do
  if [ "$#" -eq 0 ]; then
    set -- -name "$d"
  else
    set -- "$@" -o -name "$d"
  fi
done

# -prune stops the descent at each match, so the scan only reads directory
# entries down to the first dependency directory. That keeps this generator
# cheap even on the slow mount.
matches=$(
  find "$PROJECTS_MOUNT" -maxdepth "$MAX_DEPTH" -type d \( "$@" \) -prune -print 2>/dev/null |
    sed "s#^$PROJECTS_MOUNT/##" |
    LC_ALL=C sort
) || matches=""

count=$(printf '%s' "$matches" | grep -c . || true)

tmp="${OUT}.tmp"
{
  echo "# GENERATED FILE — do not edit by hand."
  echo "# Regenerate with: make masks"
  echo "# Source: scripts/generate-mask-override.sh (see ADR-009)."
  echo "#"
  echo "# Masks $count dependency/cache directories found under PROJECTS_BASE so"
  echo "# project-tree walks never touch them on the slow Windows bind mount."
  echo "services:"
  for svc in $SERVICES; do
    echo "  ${svc}:"
    if [ "$count" -eq 0 ]; then
      echo "    tmpfs: []"
      continue
    fi
    echo "    tmpfs:"
    printf '%s\n' "$matches" | while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      echo "      - ${CONTAINER_PROJECTS}/${rel}:size=${MASK_SIZE},mode=0777"
    done
  done
} > "$tmp"

mv "$tmp" "$OUT"
echo "Wrote $OUT with $count masked directories."
if [ "$count" -gt 0 ]; then
  printf '%s\n' "$matches" | sed 's/^/  - /'
fi
