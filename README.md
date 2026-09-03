# KiroCrew Docker Compose Bootstrap

A public, local-development bootstrap for running [KiroCrew](https://github.com/kirodotdev/kirocrew) with Docker Desktop and WSL2. It provides persistent agent state, Docker/Node/GitHub/Google Cloud tooling, configurable project mounts, two isolated agent instances, and localhost-only dashboards.

## Quick start

From WSL2, in this repository:

```bash
cp .env.example .env
# Set PROJECTS_BASE if your repositories are outside ./projects.
docker compose up -d
```

Authenticate each Kiro instance once when needed:

```bash
make kiro-login-a
make kiro-login-b
```

The normal startup flow is then simply `docker compose up -d`. Persistent volumes are kept across normal container recreation.

## Instances and access

| Instance | Dashboard | Container port | Persistent volume |
| --- | --- | --- | --- |
| Kiro A | http://localhost:5476 | 5476 | `kiro-a-home` |
| Kiro B | http://localhost:5477 | 5476 | `kiro-b-home` |

Both dashboards bind only to `127.0.0.1`. The project tree is available inside each agent at `/home/kirocrew/projects`.

## Documentation

- [Documentation index](docs/README.md)
- [English documentation](docs/en/README.md)
- [Documentación en español](docs/es/README.md)
- [English security guide](docs/en/security.md) · [Guía de seguridad en español](docs/es/security.md)
- [Architecture diagrams](docs/architecture/)
- [Architecture decision records](docs/en/decisions/)

The English documentation is canonical for the repository. The Spanish documentation mirrors the same operational and security guidance. Keep both language trees synchronized when behavior changes.

## Common commands

```bash
make up              # Generate masks and start both instances.
make status          # Show service and health status.
make logs            # Follow both agent logs.
make shell-a         # Open a shell in Kiro A.
make shell-b         # Open a shell in Kiro B.
make restart         # Rebuild/recreate the stack without deleting volumes.
make backup          # Back up persistent agent volumes.
make masks           # Regenerate dependency/cache tmpfs masks.
```

The optional Dockerized Make service is available through the `tools` profile:

```bash
docker compose --profile tools run --rm make status
```

See the [English command and operations guide](docs/en/README.md) for project mounts, shared networks, GCP, GitHub, troubleshooting, backups, and container verification.

## Security boundary

This project is intended for local development. The Docker socket grants root-equivalent access to the host Docker Engine, projects are writable, and Kiro A/B use `SYS_ADMIN`, `seccomp:unconfined`, and `apparmor:unconfined` for nested browser/agent sandbox compatibility on Docker Desktop/WSL2. Do not expose the dashboards to the Internet or use this bootstrap as an unreviewed multi-user service.

GCP and GitHub credentials remain local to ignored `.env` files or persistent instance volumes. They must never be committed, embedded in images, copied into documentation, or included in generated artifacts. Review [ADR-012](docs/en/decisions/ADR-012-gcloud-access-from-acp.md) before enabling ACP access to GCP credentials.

## Repository layout

```text
.
├── docker-compose.yml
├── compose/                 # Shared, Kiro A, and Kiro B Compose definitions
├── Dockerfile.kirocrew     # Local runtime additions and sandbox policy
├── Dockerfile.make         # Optional Dockerized Make image
├── Makefile                # Operational commands
├── scripts/                # Project and mount helpers
├── tests/                  # Static repository validation
├── docs/
│   ├── README.md           # Documentation index
│   ├── en/                 # English operational and decision documentation
│   ├── es/                 # Spanish translation of the same documentation
│   └── architecture/       # Interactive architecture/workflow diagrams
├── .env.example
└── kirocrew-seccomp.json   # Experimental, opt-in security profile
```

## Validation

Run these checks before submitting changes:

```bash
./tests/validate.sh
docker compose --env-file .env.example config --quiet
docker compose --profile tools build make
git diff --check
```

The static validation does not require credentials or start the agent gateways. Full runtime verification requires Docker Desktop/WSL2.

## License

This project is distributed under the [MIT License](LICENSE).
