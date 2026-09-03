# Security and Operational Limits

[Versión en español](../es/security.md)

## Trust model

This project is designed for local development. KiroCrew can read and modify mounted projects, run processes inside its container, and communicate with the Docker Engine through `/var/run/docker.sock`.

The Docker socket is effectively administrative access to the host Engine. Do not expose dashboards outside localhost or use this Compose configuration as a public or multi-user service without additional isolation review.

## Default configuration

- Dashboards are published only on `127.0.0.1`.
- KiroCrew runs as the non-root user `kirocrew`.
- `privileged: true` is not used.
- `SYS_ADMIN`, `seccomp:unconfined`, and `apparmor:unconfined` support nested Chromium/Playwright sandboxing in Docker Desktop/WSL2.
- `kirocrew-seccomp.json` is not enabled automatically. It is experimental and must be validated before use.
- The project tree is writable because the agent must modify code. Use explicit mounts to reduce scope.

## GitHub tokens

`GH_TOKEN_A` and `GH_TOKEN_B` are optional. Configure them only when the corresponding instance must use GitHub CLI or perform HTTPS Git operations.

- Keep tokens exclusively in local `.env` or a secret manager.
- Use separate tokens per instance, with the smallest possible scope.
- Revoke and replace a token if it appears in logs, history, backups, or shared files.
- Remember that a configured token is inherited by the agent's child processes.

Backups of volumes contain persistent state and may contain credentials. Do not publish them or add them to the repository.

## Review before expanding permissions

Before adding ports, mounts, capabilities, tokens, or external integrations, update an ADR and add a test demonstrating the expected boundary. Static validation does not replace a runtime test in Docker Desktop/WSL2.
