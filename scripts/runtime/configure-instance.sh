#!/usr/bin/env sh
set -eu

if [ ! -x "${HOME}/.local/bin/kiro-cli" ]; then
  curl -fsSL https://cli.kiro.dev/install | bash
fi

kirocrew setup --agent-only
playwright-cli install --skills=agents --global
kirocrew config set knowledge.max_sources "${KIROCREW_KNOWLEDGE_MAX_SOURCES}"
kirocrew config set knowledge.extraction_pool_size "${KIROCREW_KNOWLEDGE_EXTRACTION_POOL_SIZE}"
kirocrew config set knowledge.folder_ingest_chunk_budget "${KIROCREW_KNOWLEDGE_FOLDER_CHUNK_BUDGET}"
kirocrew config set --local agent.subagent_cwd_allowed_roots '["/home/kirocrew/projects","~/workspace","~/workspaces","~/workplace","~/workplaces"]'

# Git identity + GitHub credential helper for this instance (ADR-010).
# Written into the persistent home volume, so it survives restarts and
# never has to be re-run manually. `gh` itself needs no `auth login`:
# it authenticates from GH_TOKEN on every invocation.
# Remove any stale manually-created gh host config so it cannot shadow
# the per-instance token injected via the environment.
rm -f /home/kirocrew/.config/gh/hosts.yml
git config --global --replace-all user.name "${GIT_USER_NAME}"
git config --global --replace-all user.email "${GIT_USER_EMAIL}"
git config --global --replace-all credential."https://github.com".helper "!/opt/gh-cli/gh auth git-credential"
git config --global --replace-all safe.directory '*'

if kiro-cli whoami >/dev/null 2>&1; then
  touch "${KIROCREW_HOME}/.kiro_cli_setup_complete"
fi
