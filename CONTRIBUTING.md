# Contributing to KiroCrew

Thank you for helping improve KiroCrew. This repository is a local Docker Desktop/WSL2 bootstrap, so changes should preserve reproducibility, security boundaries, and a usable first-run experience.

## Before you start

1. Read the [README](README.md), [security guide](docs/en/security.md), and relevant [ADRs](docs/en/decisions/).
2. Check existing issues and pull requests before starting a substantial change.
3. Do not include credentials, private paths, customer names, generated backups, or environment-specific artifacts.
4. For a behavioral or architectural change, state the expected behavior and acceptance criteria before implementation.

## Development workflow

Use a short-lived branch based on `main`:

```bash
git switch main
git pull --ff-only
git switch -c feature/short-description
```

Keep commits focused and use an imperative message such as:

```text
feat: add runtime smoke check
fix: validate generated mask paths
docs: clarify WSL2 recovery
```

Do not commit `.env`, `docker-compose.override.yml`, volume backups, or local Kiro state.

## Validation before a pull request

Run the static checks and image builds from WSL2 with Docker Desktop running:

```bash
./tests/validate.sh
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.example --profile tools build make
docker compose --env-file .env.example build kiro-a kiro-b
git diff --check
```

If `make` is not installed in WSL, use the Dockerized helper documented in the README. For runtime changes, also verify the health endpoints and include the relevant logs in the pull request description without exposing secrets.

## Pull requests

A pull request should explain:

- What changed and why.
- Which user or operational problem it addresses.
- How it was verified.
- Any security, compatibility, migration, or rollback considerations.
- Whether English and Spanish documentation were updated together.

Keep unrelated refactors out of feature or bug-fix pull requests. New dependencies, permissions, ports, mounts, credential flows, or CI policy changes require explicit justification and review.

## Documentation and ADRs

Update the canonical English documentation and its Spanish translation when behavior or security guidance changes. Add a new sequential ADR for a decision that would be expensive to reverse; do not rewrite historical ADRs.

## Security reports

Do not disclose vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md).

## Code of conduct

All participants must follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
