# KiroCrew Docker Compose Bootstrap

[Español](../es/README.md) · [Documentation index](../README.md)

Public bootstrap for running [KiroCrew](https://github.com/kirodotdev/kirocrew) with Docker Desktop and WSL2. It includes persistence for agent state, Docker CLI + Compose inside the container, configurable access to work projects, and a dashboard published only on localhost.

The configuration contains no environment-specific paths or project names. The default value uses `./projects`; change it in `.env` to reuse existing repositories.

## Included

- Official KiroCrew image pinned by digest in `.env.example` for reproducible builds.
- `docker-cli` init service based on `docker:cli`.
- `node-cli` init service based on `node:22-slim` (Node.js, npm, npx).
- `gh-cli` init service based on `debian:trixie-slim` (GitHub CLI).
- Docker CLI and the Compose plugin injected through the `docker-bin` volume.
- Node.js CLI injected through the `node-bin` volume.
- GitHub CLI injected through the `gh-bin` volume.
- Docker CLI also available in interactive/login shells through `/etc/profile.d`.
- Two isolated instances: `kiro-a` and `kiro-b`.
- Separate persistent state in `kiro-a-home` and `kiro-b-home` volumes.
- Projects available at `/home/kirocrew/projects/<name>` for both instances.
- Dashboards at `http://localhost:5476` (Kiro A) and `http://localhost:5477` (Kiro B), with no external-interface exposure.
- `SYS_ADMIN` capability for the Chromium/Playwright sandbox.
- Shared `kirocrew-net` network for communication with project stacks.
- Makefile and helper for common operations.
- Optional `make` service for running Make inside Docker without installing it on the host.

## Architecture diagrams

Interactive diagrams generated with Archify are kept in [`docs/architecture/`](../architecture/): architecture, startup/prompt/recovery workflow, Devin → Docker Desktop → WSL → Kiro Crew sequence, and project/mount/configuration dataflow. The JSON specifications are alongside each HTML. The HTML artifacts are standalone and can be opened locally or served by a static server; GitHub may display them as code instead of executing them.

## GCP authentication inside ACP

`Dockerfile.kirocrew` preserves each instance's `gcloud` configuration and allows ACP shells to use `/home/kirocrew/.config/gcloud`. Login must be performed separately in each persistent volume (`kiro-a-home` and `kiro-b-home`):

```bash
docker compose exec -it kiro-a gcloud auth login
docker compose exec -it kiro-b gcloud auth login
docker compose exec kiro-b gcloud config set project PROJECT_ID
```

Credentials are not included in the image, repository, or `.env.example`; they persist only in the instance's local volume. This exception enables GCP access from the agent and therefore must be used only with accounts and minimum necessary permissions.

## Prerequisites

- Docker Desktop installed and running.
- WSL2 integration enabled for your Linux distribution.
- `docker` and `docker compose` available in WSL2.
- Bash available in WSL2 for helper scripts.
- `make` need not be installed on the host; the `make` service provides it inside Docker.
- A directory containing projects KiroCrew may read and modify.

The Docker socket grants root-equivalent access to the host Docker Engine. This configuration is intended for local development and must not be exposed directly to the Internet.

### Privilege model

KiroCrew runs as the non-root user `kirocrew` (UID 1000). Compose grants only the access needed for development:

- `SYS_ADMIN` for the Chromium/Playwright sandbox.
- The Docker socket group through `DOCKER_SOCKET_GID`, so Docker/Compose can run without making the process root.
- Writable project and state mounts, needed to modify code and retain memory.
- `kirocrew-net` to communicate with project stacks that explicitly connect to it.

`privileged: true`, `sudo`, and `NET_ADMIN` are not used. For nested Kiro Crew sandboxing inside Docker Desktop/WSL2, Kiro A and Kiro B use `seccomp:unconfined` and `apparmor:unconfined`; this reduces isolation and requires dashboards to remain localhost-only. The `access-test` target checks container capabilities.

`kirocrew-seccomp.json` is retained as a documented experimental profile but is not applied by default. Its compatibility must be tested for each Docker Desktop, WSL2, and architecture combination before replacing `unconfined`. See [`security.md`](security.md) for the threat model and credential configuration.

## Quick setup

From WSL2, in the project directory:

```bash
cp .env.example .env
# Edit PROJECTS_BASE if you want repositories outside ./projects
docker compose up -d
```

`kiro-a-config` and `kiro-b-config` automatically apply safe Knowledge concurrency values in their persistent volumes before starting Kiro A and Kiro B. They do not delete sessions, memory, credentials, or existing sources. Both instances are built locally from `Dockerfile.kirocrew` on the configured base image, keeping the ACP initialize timeout reproducible.

### Automatic Kiro CLI bootstrap

Each `kiro-a-config` and `kiro-b-config` service, before starting its gateway:

1. Installs Kiro CLI from `https://cli.kiro.dev/install` if `/home/kirocrew/.local/bin/kiro-cli` does not exist.
2. Runs `kirocrew setup --agent-only` to regenerate managed agent specs.
3. Reapplies Knowledge values.
4. Runs `kiro-cli whoami` and creates `.kiro_cli_setup_complete` only when the account is authenticated.

After each account's initial authentication, the normal flow is simply:

```bash
docker compose up -d
```

Login is not automated because it requires the owner's interaction with IAM Identity Center. Credentials remain in the separate `kiro-a-home` and `kiro-b-home` volumes.

The initial `PROJECTS_BASE=./projects` allows the stack to start without external paths. For native WSL2 storage, use `PROJECTS_BASE=/home/your-user/repos`; for Windows-mounted repositories use `PROJECTS_BASE=/mnt/c/Users/your-windows-user/Documents/Repositories`. `/mnt/c` paths usually have worse I/O performance than paths in the WSL2 filesystem.

### Path format by terminal

Do not mix path formats between terminals:

- From WSL2: `PROJECTS_BASE=/mnt/c/Users/your-windows-user/Documents/Repositories`.
- From PowerShell or Windows: `PROJECTS_BASE=C:/Users/your-windows-user/Documents/Repositories`.

If you run `docker compose` from PowerShell with a `/mnt/c/...` path, Docker Desktop may create an empty mount and KiroCrew will not see the repositories. When changing terminals, update the local `.env` and recreate the service.

## Commands

| Command | Description |
| --- | --- |
| `make up` | Applies safe configuration and starts KiroCrew in the background. |
| `make up-a` / `make up-b` | Rebuilds and starts only Kiro A or Kiro B from central configuration. |
| `make configure` | Reapplies Knowledge concurrency values without deleting the volume. |
| `make down` | Stops and removes containers without deleting volumes. |
| `make restart` | Stops and starts the stack again. |
| `make logs`, `make logs-a`, `make logs-b` | Follows KiroCrew or one instance's logs. |
| `make shell`, `make shell-a`, `make shell-b` | Opens an interactive shell. |
| `make status` | Shows Compose status and container health. |
| `make update` | Pulls the base image, rebuilds the local runtime, and recreates KiroCrew. |
| `make docker-test`, `make access-test`, `make node-test`, `make gh-test`, `make gcloud-test`, `make kubectl-test` | Verifies Docker/access, Node, GitHub CLI, Google Cloud CLI, or kubectl. |
| `make token` | Generates an authenticated dashboard URL. |
| `make kiro-login-a`, `make kiro-login-b` | Starts interactive Kiro CLI login for each instance. |
| `make backup` | Creates a timestamped backup of persistent state. |
| `make project-up NAME=X`, `make project-down NAME=X` | Starts or stops a mounted project's Docker stack. |

The `make` service runs under the `tools` profile. Examples include `docker compose run --rm make up`, `configure`, `down`, `restart`, `logs`, `shell`, `status`, `update`, `docker-test`, `node-test`, `gh-test`, `kiro-login-a`, `kiro-login-b`, `access-test`, `token`, `backup`, `project-up NAME=demo-app`, and `project-down NAME=demo-app`. For nested Compose mounts, `PROJECTS_BASE` must be an absolute path visible to Docker Desktop/WSL2; the relative `./projects` is suitable for the normal stack.

Direct equivalents:

```bash
docker compose up -d
docker compose down
docker compose logs -f kiro-a kiro-b
docker compose exec kiro-a bash
docker compose up -d --force-recreate kiro-a kiro-b
```

## Work projects and shared network

`PROJECTS_BASE/<project-name>` is mounted as `/home/kirocrew/projects/<project-name>`. For reduced privilege, replace the whole-directory mount in `compose/kiro-a.yml` and `compose/kiro-b.yml` with explicit mounts. `./scripts/add-project.sh demo-app` (or with `/absolute/path/to/demo-app`) validates and prints a block without modifying Compose.

KiroCrew creates `kirocrew-net`. A project stack that needs reachability must declare it external and explicitly attach services; the network does not automatically connect all stacks. Start KiroCrew first. `make project-up NAME=demo-app` defaults to `PROJECT_PROFILE=dev` and looks for `demo-app/infra/docker/compose.yml`; both values can be changed in `.env`.

## Dashboards and verification

Kiro A is at [http://localhost:5476](http://localhost:5476), and Kiro B at [http://localhost:5477](http://localhost:5477); both bind only to `127.0.0.1`.

```bash
docker exec kiro-a docker ps
docker exec kiro-a docker compose version
docker compose run --rm make token
```

The token is printed only in the terminal; do not store it in Git or share it publicly.

## Kiro CLI and initialize errors

A healthy dashboard does not prove chat sessions can initialize if Kiro CLI is unauthenticated. Use `docker compose run --rm make kiro-login-a` and repeat with `kiro-login-b`, then verify with `docker compose exec kiro-a kiro-cli whoami` and the equivalent `kiro-b` command. Never share `kiro-a-home` and `kiro-b-home` because they contain independent authentication state.

`Request initialize timed out` can also occur when selected-agent MCPs do not respond. The full `kirocrew` agent may depend on `kirocrew-core`, `kirocrew-computer`, `kirocrew-cron`, `auto-improvement`, and `mochi`; temporarily use `kirocrew-lite` (which loads no MCPs), then restore `default` after repair. Recommended settings are `session.eager_spawn=false`, `agent.subagent_auto_max=8`, `taskrunner.max_parallel_steps=8`, `mcp_gateway.max_backends=16`, `knowledge.max_sources=100`, `knowledge.extraction_pool_size=1`, and `knowledge.folder_ingest_chunk_budget=25`. Reapply changes with `make configure`.

`Request initialize timed out after 30s` occurs during the ACP handshake, before the message is processed. The local runtime built by `Dockerfile.kirocrew` raises the budget to `KIROCREW_ACP_INIT_TIMEOUT_SECS` (120 seconds by default) at the `initialize` call site (see ADR-006 and ADR-008). Do not confuse this with `chat_turn_timeout_secs`. Inspect with `docker exec kiro-a kirocrew config get agent.session_start_timeout_secs` and `docker inspect kiro-a kiro-b --format '{{.Name}} {{range .Config.Env}}{{println .}}{{end}}' | grep KIROCREW_ACP_INIT_TIMEOUT_SECS`. A timeout at the configured budget indicates host contention; use `docker stats --no-stream`, MCP log checks, and `docker update --cpus 1.0 <container>` as needed. Native WSL2 paths generally outperform Windows bind mounts for many small files.

## Dependency-tree masking

On Windows bind mounts, directory traversal costs about ~1 ms per entry. A large `node_modules` can produce `Request initialize timed out`; `make masks` scans `PROJECTS_BASE` and generates `docker-compose.override.yml` with an empty `tmpfs` over dependency/cache directories. The reference `example-org/sample-repo` traversal drops from 58 213 files / 64.1 s to 2 471 files / 6.3 s (see ADR-009).

```bash
make masks
make mask-report PROJECT=example-org/sample-repo
```

`up`, `restart`, and `update` chain `masks`. After cloning or installing dependencies, run `make masks`. `KIROCREW_MASK_DIRS` controls the list; `.git`, `build`, and `dist` intentionally remain visible. Masked directories appear empty, and installs go to `KIROCREW_MASK_TMPFS_SIZE` (1 GB by default), disappearing on restart. The generated `docker-compose.override.yml` is host-specific, ignored by Git, and must not be edited manually.

## GitHub identity per instance

Configure `GH_USER_A`, `GH_TOKEN_A`, `GH_USER_B`, and `GH_TOKEN_B` in `.env` (optional `GH_EMAIL_A` and `GH_EMAIL_B`). The config services write `~/.gitconfig` with `user.name`, `user.email`, and the `gh` credential helper. `gh` reads `GH_TOKEN` on each invocation, so no `gh auth login` is required. Use `make gh-identity` and `make gh-test`. PATs must never go to Git; each instance pushes as its own account and HTTPS remotes are required. If a token expires, update `.env` and restart the corresponding container.

## Node.js, persistence, backup, and troubleshooting

Node.js 22, npm, npx, and corepack are injected by `node-cli`; verify with `docker compose run --rm make node-test` and `docker exec kiro-a bash -l -c 'node --version && npm --version && npx --version'`. The `node-bin` volume is a tool cache; recreate it with `docker compose up -d --force-recreate` after changing the sidecar version or contents. The Dockerized Make service prioritizes Compose-provided variables over `.env` values so host paths remain correct for nested Compose.

Persistent volumes `kiro-a-home` and `kiro-b-home` contain memory, configuration, credentials, and history; do not run `docker volume rm kiro-a-home kiro-b-home` or `docker compose down -v` without `make backup`. The equivalent is `docker compose run --rm make backup`.

For Docker permissions check `docker version`, `docker compose version`, `ls -l /var/run/docker.sock`, and `stat -c '%g' /var/run/docker.sock`; update `DOCKER_SOCKET_GID` in `.env`, inspect `docker compose logs docker-cli`, and run `docker compose up -d --force-recreate`. On Docker Desktop + WSL2 the socket is normally `root:root`, so `DOCKER_SOCKET_GID=0` is expected while KiroCrew remains the internal `kirocrew` user.

Check project mounts with:

```bash
set -a
source .env
set +a
ls -la "$PROJECTS_BASE"
docker compose up -d --force-recreate kiro-a kiro-b
```

For a corrupt volume, make and validate a backup first; remove or restore it only afterward. Normal `docker compose down` does not erase persistent state. The image installs `ffmpeg`, `libreoffice` (including Impress and Draw), Chromium runtime libraries, and `@playwright/cli` 0.1.18. The `node-cli` sidecar downloads Chromium to `playwright-browsers` and each instance registers skills at `/home/kirocrew/.agents/skills/playwright-cli`. Verify with `docker compose exec kiro-a libreoffice --headless --version` and the equivalent Kiro B command; browser examples are `docker compose exec kiro-a playwright-cli open http://host.docker.internal:3000` and the Kiro B command with `--browser=chromium`. `SYS_ADMIN` is required by the Chromium sandbox.

## Structure

See the repository's `docker-compose.yml`, `compose/shared.yml`, `compose/kiro-a.yml`, `compose/kiro-b.yml`, `Dockerfile.make`, `.dockerignore`, `.env.example`, `Makefile`, `projects/.gitkeep`, `scripts/`, `tests/validate.sh`, `.github/workflows/validate.yml`, and `docs/` documentation.

## License and contributing

This project is distributed under the MIT license; see [`LICENSE`](../../LICENSE). Public configurations must use placeholders and remain free of personal paths, private project names, and credentials. Before opening a PR, run:

```bash
./tests/validate.sh
docker compose --profile tools build make
git diff --check
```

Validation does not start KiroCrew or require credentials. Full runtime validation requires Docker Desktop/WSL2 and the quick setup above.
