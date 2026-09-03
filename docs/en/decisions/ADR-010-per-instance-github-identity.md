# ADR-010: Per-instance GitHub identity

## Status
Accepted (2026-08-18).

## Context

Kiro Crew runs `kiro-a` and `kiro-b`. A shared `GH_TOKEN` forced one GitHub account for both. Each instance receives its own operator-supplied GitHub identity through `.env`; the documentation uses no real account names. The agent must run `gh` and Git operations without repeating manual setup after restarts.

`GH_TOKEN` is not in `_AGENT_DENIED_ENV_KEYS` or `_SENSITIVE_ENV_PREFIXES` in `kiro_crew/sandbox.py`, so child processes inherit it. `GIT_ASKPASS` is present and is removed, making it unsuitable. `gh auth git-credential` uses `GH_TOKEN` but needs a helper in `~/.gitconfig`.

## Decision

1. Pass `GH_USER_A` / `GH_TOKEN_A` to `kiro-a` and `GH_USER_B` / `GH_TOKEN_B` to `kiro-b`.
2. Config services write `~/.gitconfig` in each persistent volume with `user.name`, `user.email` (default `<GH_USER_*>@users.noreply.github.com`), the `credential."https://github.com".helper` pointing to `/opt/gh-cli/gh auth git-credential`, and `safe.directory '*'`.
3. `gh` reads `GH_TOKEN` and `GH_HOST` on each invocation; identity survives restarts without `gh auth login`.
4. `gh-test` and `gh-identity` verify both accounts.

## Alternatives Considered

Interactive `gh auth login` was rejected because `~/.config/gh/hosts.yml` persistence is not guaranteed and recreation would require interaction. `GIT_ASKPASS` is removed by kiro-crew. A shared credential volume would mix identities. SSH keys add mounts while projects use HTTPS.

## Consequences

Each instance has an isolated GitHub account. PATs remain in `.env` (`.gitignore`) and out of the repository. Updating an expired token and restarting is sufficient. `git push` and `gh` work when the destination is accessible to that account. Noreply addresses avoid exposing personal email.
