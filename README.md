# KiroCrew Docker Compose Bootstrap

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) · [Documentación en español](docs/es/README.md)

![KiroCrew local agent workspace](docs/assets/kirocrew-banner.svg)

Local bootstrap for running [KiroCrew](https://github.com/kirodotdev/kirocrew) with Docker and two isolated agent instances. It provides persistent agent state, Docker/Node/GitHub/Google Cloud tooling, configurable project mounts, and dashboards bound to localhost.

## Documentation

The English documentation is the default and canonical reference:

- [English documentation and operations guide](docs/en/README.md)
- [Architecture diagrams](docs/architecture/)
- [Engineering budgets](docs/operations/budgets.md)
- [Security guide](docs/en/security.md)
- [Architecture decision records](docs/en/decisions/)
- [Agent instructions](AGENTS.md) · [RTK command guidance](RTK.md)

For Spanish, use the maintained translation:

- [Documentación y guía de operaciones en español](docs/es/README.md)
- [Guía de seguridad en español](docs/es/security.md)
- [Registros de decisiones en español](docs/es/decisions/)

## Quick start

Choose the setup for your host operating system.

### GNU/Linux

Requirements:

- A supported GNU/Linux distribution.
- Docker Engine with the Compose v2 plugin.
- Bash for the helper scripts.
- On hosts without AppArmor (for example Fedora, RHEL, or Arch without the apparmor module), set `KIROCREW_APPARMOR_OPT=no-new-privileges:false` in `.env`; the default `apparmor:unconfined` is rejected by the runtime there. Check with `docker info --format '{{.SecurityOptions}}'`.
- `make` is optional; the Dockerized `make` service is available through the `tools` profile.

Run from the repository directory:

```bash
cp .env.example .env
# Set PROJECTS_BASE if your repositories are outside ./projects.
make up
make status
```

If Make is not installed:

```bash
docker compose --profile tools run --rm make up
docker compose --profile tools run --rm make status
```

Keeping the repository and projects on a native Linux filesystem is recommended for better file traversal performance.

### Windows

Requirements:

- Windows 10/11 with WSL2 enabled.
- Docker Desktop with the WSL2 backend and integration enabled for your Linux distribution.
- A WSL2 distribution with `docker` and `docker compose` available.

Run the project commands from a WSL2 terminal, not from Windows PowerShell:

```bash
cp .env.example .env
# Set PROJECTS_BASE if your repositories are outside ./projects.
make up
make status
```

For better performance, keep the repository and active projects inside the WSL2 Linux filesystem instead of `/mnt/c/...` when practical.

## Instances and access

| Instance | Dashboard | Container port | Persistent volume |
| --- | --- | --- | --- |
| Kiro A | http://localhost:5476 | 5476 | `kiro-a-home` |
| Kiro B | http://localhost:5477 | 5476 | `kiro-b-home` |

Both dashboards bind only to `127.0.0.1`. Projects are available inside each agent at `/home/kirocrew/projects`.

Authenticate each Kiro instance when needed:

```bash
make kiro-login-a
make kiro-login-b
```

## Daily operations

| Command | Purpose |
| --- | --- |
| `make up` | Generate masks and start both instances. |
| `make up-a` / `make up-b` | Start only one instance. |
| `make status` | Show services and healthchecks. |
| `make logs` | Follow Kiro A and Kiro B logs. |
| `make shell-a` / `make shell-b` | Open a shell inside an instance. |
| `make restart` | Recreate the stack without deleting volumes. |
| `make configure` | Re-run persistent instance configuration. |
| `make masks` | Regenerate masks for slow host mounts. |
| `make backup` | Back up persistent agent volumes. |
| `make ssh-test` | Verify OpenSSH and `gcloud compute ssh`. |
| `make rtk-init` | Reapply project-level RTK instructions for agents. |
| `make down` | Stop and remove this Compose stack. |

To generate a mount block for another project without editing files automatically:

```bash
./scripts/project/add-project.sh demo-app
./scripts/project/add-project.sh demo-app /absolute/path/to/demo-app
```

## Community and maintenance

- [Contributing](CONTRIBUTING.md): workflow, validation, and pull requests.
- [Code of Conduct](CODE_OF_CONDUCT.md): participation and community standards.
- [Security](SECURITY.md): private vulnerability reporting and security boundaries.
- [License](LICENSE): MIT license.
- [Engineering budgets](docs/operations/budgets.md): CI, runtime, release, backup, and recovery budgets.

## Architecture

The stack has three layers:

1. **Shared tooling services** in `compose/shared.yml`: Docker CLI, Node/Playwright, and GitHub CLI sidecars exposed through shared volumes.
2. **Configuration services** (`kiro-a-config` and `kiro-b-config`): initialize persistent state, Git identity, and Knowledge settings before each agent starts.
3. **Kiro instances** (`kiro-a` and `kiro-b`): run the local runtime built from `docker/Dockerfile.kirocrew`, mount projects, and expose localhost dashboards.

The root `docker-compose.yml` includes the modular definitions in `compose/`. The `Makefile` contains repeatable operations. `docker-compose.override.yml` is generated locally to mask dependency/cache directories inside slow host mounts.

## Security boundary

This project is intended for local development, not as a public multi-user service. The agents mount the host Docker socket, have write access to projects, and use `SYS_ADMIN`, `seccomp:unconfined`, and `apparmor:unconfined` for nested sandbox compatibility. Do not expose the dashboards to the Internet.

GCP, GitHub, and Kiro credentials must remain in ignored `.env` files or persistent instance volumes. Never commit them, embed them in images, copy them into documentation, or include them in generated artifacts. Review [ADR-012](docs/en/decisions/ADR-012-gcloud-access-from-acp.md) before enabling ACP access to GCP credentials.

## Repository structure

```text
.
├── docker-compose.yml             # Compose entry point
├── compose/                       # Modular Compose services
│   ├── shared.yml
│   ├── kiro-a.yml
│   └── kiro-b.yml
├── docker/                        # Local images
│   ├── Dockerfile.kirocrew
│   └── Dockerfile.make
├── Makefile                       # Repeatable operations
├── scripts/                       # Executable helpers
│   ├── project/add-project.sh
│   └── performance/generate-mask-override.sh
├── tests/validate.sh              # Static repository validation
├── docs/                          # Operations, security, ADRs, assets, and diagrams
│   ├── assets/kirocrew-banner.svg
│   └── operations/budgets.md
├── AGENTS.md                      # Agent workflow instructions
├── RTK.md                         # RTK output optimization guidance
├── CODE_OF_CONDUCT.md             # GitHub community standards
├── CONTRIBUTING.md                # Contribution workflow
├── SECURITY.md                    # Repository security policy
├── LICENSE                        # MIT license
├── projects/.gitkeep              # Default local project mount point
├── .env.example                   # Public configuration template
└── kirocrew-seccomp.json          # Experimental opt-in profile
```

Local files such as `.env`, `docker-compose.override.yml`, `.kiro/`, and volume backups are ignored and are not part of the repository. Regenerate the override with `make masks`; do not edit it manually.

## Validation

Run these checks before submitting changes:

```bash
./tests/validate.sh
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.example --profile tools build make
docker compose --env-file .env.example build kiro-a kiro-b
git diff --check
```

Static validation does not require credentials. Image builds and runtime verification require Docker to be available on GNU/Linux or Docker Desktop with WSL2 integration on Windows.

## License

This project is distributed under the [MIT License](LICENSE).
