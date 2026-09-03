# ADR-007: Run two isolated Kiro Crew instances

## Status
Accepted

## Context

Two Kiro Crew gateways must run on one Docker host, each with a different Kiro account authenticated through IAM Identity Center. A single instance cannot safely share the other account's authentication state, memory, conversations, or configuration. Docker Desktop/WSL2 also blocks Kiro Crew's nested Linux sandbox under the default seccomp/AppArmor policy.

## Decision

Define two explicit Compose services: `kiro-a` at `127.0.0.1:5476` and `kiro-b` at `127.0.0.1:5477`. Each uses an independent volume (`kiro-a-home` and `kiro-b-home`) and exposes `KIRO_HOME` and `KIROCREW_HOME` within it. Init services (`kiro-a-config` and `kiro-b-config`) bootstrap Kiro CLI, regenerate agent specs, and mark setup complete when `kiro-cli whoami` confirms a valid session.

Interactive authentication is not automated: each account logs in once with `kiro-cli login`, and state persists in its instance volume. Both instances use `seccomp:unconfined` and `apparmor:unconfined` for the required nested sandbox; dashboards remain localhost-only and the Docker socket provides the required development access.

## Alternatives Considered

A shared volume was rejected because it would mix credentials, memory, and sessions. Compose profiles alone do not isolate persistent state or credentials. The default seccomp/AppArmor sandbox cannot complete the nested mount namespace probe. OAuth automation was rejected because IAM Identity Center requires owner interaction and credentials must not be simulated or stored in the repository.

## Consequences

- `docker compose up -d` starts and configures both instances.
- First authentication for each account remains interactive.
- Each account keeps credentials and data independently.
- Bootstrap reinstalls Kiro CLI if the user binary is absent.
- Isolation is reduced by `seccomp:unconfined` and `apparmor:unconfined`; dashboards must not be published outside localhost.
- `kiro-a-home` and `kiro-b-home` must be included in backups.
