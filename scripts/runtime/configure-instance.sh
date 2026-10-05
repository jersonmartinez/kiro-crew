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

# Auto-improvement provider-runner gate (ADR-014). The app's member-agent team
# refuses to do work while the gateway's effective sandbox is below 'strict',
# because agent-run commands could read on-disk credential stores. Two
# supported operator opt-ins are reconciled from the environment:
#
#   KIROCREW_SANDBOX_MIN_LEVEL (off|standard|cc|strict) seeds
#   ~/.kiro/crew/security_policy.json — the local governance ceiling that
#   clamps every spawn up to the given floor. A policy file this stack did
#   not generate is never touched; unsetting the variable removes a
#   stack-generated floor from a managed file (and the file itself when it
#   carries nothing else).
#
#   KIROCREW_AUTO_IMPROVEMENT_ACCEPT_UNSANDBOXED_RISK=1 records the app's
#   explicit acceptUnsandboxedAgentRisk consent instead, scoped to
#   auto-improvement runs only; 0 revokes a grant written here, and an empty
#   value leaves a dashboard-made choice untouched.
python3 - "${KIROCREW_HOME}" "${KIROCREW_SANDBOX_MIN_LEVEL:-}" <<'PY'
import json
import os
import sys

crew_home, level = sys.argv[1], sys.argv[2]
path = os.path.join(crew_home, "security_policy.json")
issuer = "kiro-crew-compose"
levels = ("off", "standard", "cc", "strict")
skeleton = {"version": 1, "boot": {}, "identity": {"issuer": issuer}}

if level and level not in levels:
    sys.exit(
        "configure-instance: invalid KIROCREW_SANDBOX_MIN_LEVEL "
        f"{level!r} (expected one of: {', '.join(levels)})"
    )

try:
    with open(path, encoding="utf-8") as handle:
        doc = json.load(handle)
    if not isinstance(doc, dict):
        doc = False
except FileNotFoundError:
    doc = None
except (OSError, ValueError) as exc:
    # A malformed trust root is never rewritten by provisioning.
    print(f"configure-instance: {path} unreadable ({exc}); left untouched", file=sys.stderr)
    doc = False

managed = isinstance(doc, dict) and (doc.get("identity") or {}).get("issuer") == issuer

if doc is not None and not managed:
    if level:
        print(
            f"configure-instance: {path} exists and is not managed by this "
            "stack; leaving it untouched",
            file=sys.stderr,
        )
elif level:
    if doc is None:
        doc = {"version": 1, "boot": {}, "identity": {"issuer": issuer}}
    doc.setdefault("identity", {})["issuer"] = issuer
    sandbox = doc.get("sandbox")
    if not isinstance(sandbox, dict):
        sandbox = {}
        doc["sandbox"] = sandbox
    if sandbox.get("min_level") != level:
        sandbox["min_level"] = level
        tmp = f"{path}.tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(doc, handle, indent=2)
            handle.write("\n")
        os.replace(tmp, path)
        print(f"configure-instance: {path} now carries sandbox.min_level={level}")
elif managed:
    sandbox = doc.get("sandbox")
    if isinstance(sandbox, dict):
        sandbox.pop("min_level", None)
        if not sandbox:
            doc.pop("sandbox", None)
    if set(doc) <= set(skeleton):
        os.remove(path)
        print(f"configure-instance: removed stack-managed {path}")
    else:
        tmp = f"{path}.tmp"
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(doc, handle, indent=2)
            handle.write("\n")
        os.replace(tmp, path)
        print(f"configure-instance: dropped sandbox.min_level from {path}")
PY

if [ -n "${KIROCREW_AUTO_IMPROVEMENT_ACCEPT_UNSANDBOXED_RISK:-}" ]; then
python3 - "${KIROCREW_HOME}/apps/auto-improvement/data/config.json" \
    "${KIROCREW_AUTO_IMPROVEMENT_ACCEPT_UNSANDBOXED_RISK}" <<'PY'
import json
import os
import sys

path, raw = sys.argv[1], sys.argv[2]
if raw not in ("0", "1"):
    sys.exit(
        "configure-instance: invalid "
        f"KIROCREW_AUTO_IMPROVEMENT_ACCEPT_UNSANDBOXED_RISK {raw!r} (expected 0 or 1)"
    )
grant = raw == "1"
try:
    with open(path, encoding="utf-8") as handle:
        cfg = json.load(handle)
    if not isinstance(cfg, dict):
        cfg = {}
except (OSError, ValueError):
    cfg = {}

changed = False
if grant and cfg.get("acceptUnsandboxedAgentRisk") is not True:
    cfg["acceptUnsandboxedAgentRisk"] = True
    changed = True
elif not grant and "acceptUnsandboxedAgentRisk" in cfg:
    cfg.pop("acceptUnsandboxedAgentRisk")
    changed = True

if changed:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(cfg, handle, indent=2)
        handle.write("\n")
    os.replace(tmp, path)
    state = "granted" if grant else "revoked"
    print(f"configure-instance: {path} acceptUnsandboxedAgentRisk {state}")
PY
fi

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
