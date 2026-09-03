# KiroCrew Docker Compose Bootstrap

[English](../en/README.md) · [Documentation index](../README.md)

Public bootstrap for running [KiroCrew](https://github.com/kirodotdev/kirocrew) with Docker Desktop and WSL2. It includes persistence for agent state, Docker CLI + Compose inside the container, configurable access to work projects, and a dashboard published only on localhost.

The configuration contains no environment-specific paths or project names. The default value uses `./projects`; you can change it in your `.env` to reuse existing repositories.

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
- Separate persistent state in the `kiro-a-home` and `kiro-b-home` volumes.
- Projects available at `/home/kirocrew/projects/<name>` for both instances.
- Dashboards at `http://localhost:5476` (Kiro A) and `http://localhost:5477` (Kiro B), with no exposure on external interfaces.
- `SYS_ADMIN` capability for the Chromium/Playwright sandbox.
- Shared `kirocrew-net` network for communication with project stacks.
- Makefile and helper for common operations.
- Optional `make` service for running Make inside Docker without installing it on the host.

## Architecture diagrams

Interactive diagrams generated with Archify are maintained in [`../architecture/`](../architecture/):

- [Architecture](../architecture/kiro-crew-architecture.html)
- [Startup, prompts, and recovery workflow](../architecture/kiro-crew-workflow.html)
- [Devin → Docker Desktop → WSL → Kiro Crew sequence](../architecture/kiro-crew-sequence.html)
- [Projects, mounts, and configuration dataflow](../architecture/kiro-crew-dataflow.html)

The JSON specifications are next to each HTML file; generated browser evidence is kept outside Git. The HTML files are standalone artifacts: they can be opened locally or served from a static server; GitHub may display the file as code instead of executing its contents.

## GCP authentication inside ACP

`Dockerfile.kirocrew` preserves each instance's `gcloud` configuration and allows ACP shells to use `/home/kirocrew/.config/gcloud`. Login must be performed separately in each persistent volume (`kiro-a-home` and `kiro-b-home`):

```bash
docker compose exec -it kiro-a gcloud auth login
docker compose exec -it kiro-b gcloud auth login
docker compose exec kiro-b gcloud config set project PROJECT_ID
```

Credentials are not included in the image, repository, or `.env.example`; they persist only in the instance's local volume. This exception enables GCP access from the agent and therefore must be used only with accounts and the minimum necessary permissions.

## Prerequisites

- Docker Desktop installed and running.
- WSL2 integration enabled for your Linux distribution.
- `docker` and `docker compose` available in WSL2.
- Bash available in WSL2 for helper scripts.
- `make` does not need to be installed on the host; the `make` service provides it inside Docker.
- A directory for the projects KiroCrew may read and modify.

The Docker socket grants root-equivalent access to the host Docker Engine. Therefore, this configuration is intended for local development and must not be exposed directly to the Internet.

### Privilege model

KiroCrew runs as the non-root user `kirocrew` (UID 1000). Compose grants it only the access needed for the development workflow:

- `SYS_ADMIN` for the Chromium/Playwright sandbox.
- The Docker socket group through `DOCKER_SOCKET_GID`, to run Docker/Compose without turning the process into root.
- Writable project and state mounts, required to modify code and preserve memory.
- The `kirocrew-net` network to communicate with project stacks that explicitly connect to it.

`privileged: true`, `sudo`, and `NET_ADMIN` are not used. For Kiro Crew's nested sandbox to work inside Docker Desktop/WSL2, Kiro A and Kiro B use `seccomp:unconfined` and `apparmor:unconfined`; this reduces isolation and requires keeping the dashboards limited to localhost. The `access-test` target can check container capabilities.

`kirocrew-seccomp.json` is retained as a documented experimental profile, but is not applied by default: its compatibility must be tested with each Docker Desktop, WSL2, and architecture combination before replacing `unconfined`. See [`security.md`](security.md) for the threat model and credential configuration.

## Quick setup

From WSL2, in the project directory:

```bash
cp .env.example .env
# Edit PROJECTS_BASE if you want to use repositories outside ./projects
docker compose up -d
```

The `kiro-a-config` and `kiro-b-config` services automatically apply safe Knowledge concurrency values in their respective persistent volumes before starting Kiro A and Kiro B. They do not delete sessions, memory, credentials, or existing sources. Both instances are built locally from `Dockerfile.kirocrew` on the configured base image, to keep a reproducible ACP initialize timeout.

### Automatic Kiro CLI bootstrap

Each `kiro-a-config` and `kiro-b-config` service runs this bootstrap before starting its gateway:

1. Installs Kiro CLI from `https://cli.kiro.dev/install` if `/home/kirocrew/.local/bin/kiro-cli` does not exist.
2. Runs `kirocrew setup --agent-only` to regenerate the managed agent specs.
3. Reapplies the Knowledge values.
4. Runs `kiro-cli whoami` and creates `.kiro_cli_setup_complete` only when the account is already authenticated.

Therefore, after each account's initial authentication, the normal workflow is reduced to:

```bash
docker compose up -d
```

Login is not automated because it requires the owner's interaction with IAM Identity Center. Credentials remain in the separate `kiro-a-home` and `kiro-b-home` volumes.

The initial `PROJECTS_BASE=./projects` value allows the stack to start without creating external paths. To use the native WSL2 filesystem, for example:

```dotenv
PROJECTS_BASE=/home/your-user/repos
```

On Windows with repositories under a mounted drive, use a Linux path visible from WSL2:

```dotenv
PROJECTS_BASE=/mnt/c/Users/your-windows-user/Documents/Repositories
```

Paths under `/mnt/c` usually have worse I/O performance than paths inside the WSL2 filesystem.

### Path format by terminal

Do not mix path formats between terminals:

- From WSL2: `PROJECTS_BASE=/mnt/c/Users/your-windows-user/Documents/Repositories`.
- From PowerShell or Windows: `PROJECTS_BASE=C:/Users/your-windows-user/Documents/Repositories`.

If you run `docker compose` from PowerShell with a `/mnt/c/...` path, Docker Desktop may create an empty mount and KiroCrew will not see the repositories. If you change terminals, update the local `.env` and recreate the service.

## Commands

| Command | Description |
| --- | --- |
| `make up` | Applies the safe configuration and then starts KiroCrew in the background. |
| `make up-a` | Rebuilds and starts only Kiro A from the central configuration. |
| `make up-b` | Rebuilds and starts only Kiro B from the central configuration. |
| `make configure` | Reapplies Knowledge concurrency values without deleting the volume. |
| `make down` | Stops and removes containers without deleting volumes. |
| `make restart` | Stops and starts the stack again. |
| `make logs` | Follows KiroCrew logs. |
| `make logs-a` / `make logs-b` | Follows the logs for one specific instance. |
| `make shell` | Opens an interactive `bash` inside KiroCrew. |
| `make shell-a` / `make shell-b` | Opens a shell in one specific instance. |
| `make status` | Shows Compose status and container health. |
| `make update` | Pulls the base image, rebuilds the local runtime, and recreates KiroCrew. |
| `make docker-test` | Runs `docker ps` inside KiroCrew. |
| `make access-test` | Verifies user, write access, Docker, and Node inside KiroCrew. |
| `make token` | Generates an authenticated dashboard URL. |
| `make node-test` | Verifies Node.js and npm inside KiroCrew. |
| `make gh-test` | Verifies GitHub CLI and its authentication status. |
| `make gcloud-test` | Verifies Google Cloud CLI, accounts, and active configuration. |
| `make kubectl-test` | Verifies kubectl and the authentication plugin for GKE. |
| `make kiro-login-a` | Starts interactive Kiro CLI login for Kiro A. |
| `make kiro-login-b` | Starts interactive Kiro CLI login for Kiro B. |
| `make backup` | Creates a timestamped backup of persistent state. |
| `make project-up NAME=X` | Starts the Docker stack for a mounted project. |
| `make project-down NAME=X` | Stops the Docker stack for a mounted project. |

### Using Make without installing it on the host

The `make` service starts under the `tools` profile and uses an image based on `docker:cli` with Make installed. Run targets with the Docker CLI:

```bash
docker compose run --rm make up
docker compose run --rm make configure
docker compose run --rm make down
docker compose run --rm make restart
docker compose run --rm make logs
docker compose run --rm make shell
docker compose run --rm make status
docker compose run --rm make update
docker compose run --rm make docker-test
docker compose run --rm make node-test
docker compose run --rm make gh-test
docker compose run --rm make kiro-login-a
# Repeat for the second account:
docker compose run --rm make kiro-login-b
docker compose run --rm make access-test
docker compose run --rm make token
docker compose run --rm make backup
docker compose run --rm make project-up NAME=demo-app
docker compose run --rm make project-down NAME=demo-app
```

For Compose to mount projects when running from the Make container, `PROJECTS_BASE` must be an absolute path visible to Docker Desktop/WSL2. The recommended local value already meets this requirement, for example `/mnt/c/Users/your-windows-user/Documents/Repositories`. The relative `./projects` value works for the normal stack; change it to an absolute path if you will use the `make` service.

Direct equivalents:

```bash
docker compose up -d
docker compose down
docker compose logs -f kiro-a kiro-b
docker compose exec kiro-a bash
docker compose up -d --force-recreate kiro-a kiro-b
```

## Work projects

By default, the directory configured in `PROJECTS_BASE` is mounted as follows:

```text
PROJECTS_BASE/<project-name>
  -> /home/kirocrew/projects/<project-name>
```

For example, a repository located at `./projects/demo-app` appears inside KiroCrew as `/home/kirocrew/projects/demo-app`.

Mounting the entire directory is convenient for a bootstrap. If you need lower privilege, replace it in `compose/kiro-a.yml` and `compose/kiro-b.yml` with explicit mounts:

```yaml
      - ${PROJECTS_BASE}/demo-app:/home/kirocrew/projects/demo-app
      - ${PROJECTS_BASE}/another-app:/home/kirocrew/projects/another-app
```

To generate a block for a specific project:

```bash
./scripts/add-project.sh demo-app
./scripts/add-project.sh demo-app /absolute/path/to/demo-app
```

The helper validates the name and that the directory exists. It only prints the block; it does not automatically modify Compose, to prevent accidental changes.

### Project stacks and shared network

KiroCrew creates the Docker network `kirocrew-net`. A project stack that needs to be accessible from KiroCrew must declare that network as external and explicitly connect the required services:

```yaml
networks:
  kirocrew-net:
    external: true

services:
  app:
    networks:
      - default
      - kirocrew-net
```

Start KiroCrew first with `docker compose up -d` or `docker compose run --rm make up`. The network name must match exactly; the network does not automatically connect all stacks.

`make project-up NAME=demo-app` uses `PROJECT_PROFILE=dev` by default and looks for `demo-app/infra/docker/compose.yml`. You can change both values in `.env`.

## Dashboards

- Kiro A: [http://localhost:5476](http://localhost:5476)
- Kiro B: [http://localhost:5477](http://localhost:5477)

Both ports are limited to `127.0.0.1`.

## Verifying Docker inside KiroCrew

```bash
docker exec kiro-a docker ps
docker exec kiro-a docker compose version
```

The first command should show the containers visible to Docker Desktop. The second confirms that the Compose plugin was injected by the `docker-cli` service.

To generate an authenticated dashboard link:

```bash
docker compose run --rm make token
```

The token is printed only in the terminal; do not store it in Git or share it publicly.

## Kiro CLI and initialization errors

The dashboard may be healthy even when chat sessions cannot initialize if Kiro CLI is unauthenticated. Complete login through the device flow from an interactive terminal:

```bash
docker compose run --rm make kiro-login-a
# Repeat for the second account:
docker compose run --rm make kiro-login-b
```

Verify that each instance is associated with the correct account:

```bash
docker compose exec kiro-a kiro-cli whoami
docker compose exec kiro-b kiro-cli whoami
```

Do not share the `kiro-a-home` and `kiro-b-home` volumes: they contain independent authentication state for each account.

The `Request initialize timed out` message can also appear when the selected agent loads MCPs that do not respond. The full `kirocrew` agent may depend on `kirocrew-core`, `kirocrew-computer`, `kirocrew-cron`, `auto-improvement`, and `mochi`; if any fails during the handshake, temporarily use the `kirocrew-lite` agent, which does not load MCPs:

```bash
docker exec kiro-a kirocrew config set agent.default_agent kirocrew-lite
docker compose up -d --force-recreate kiro-a kiro-b
```

To return to the full agent after repairing its MCPs:

```bash
docker exec kiro-a kirocrew config set agent.default_agent default
docker compose up -d --force-recreate kiro-a kiro-b
```

The recommended local configuration uses `session.eager_spawn=false`, `agent.subagent_auto_max=8`, `taskrunner.max_parallel_steps=8`, and `mcp_gateway.max_backends=16`. For Knowledge, `kiro-a-config` and `kiro-b-config` apply `knowledge.max_sources=100`, `knowledge.extraction_pool_size=1`, and `knowledge.folder_ingest_chunk_budget=25`. These values are stored in the separate `kiro-a-home` and `kiro-b-home` volumes; the following commands inspect Kiro A:

```bash
docker exec kiro-a kirocrew config get session.eager_spawn
docker exec kiro-a kirocrew config get agent.subagent_auto_max
docker exec kiro-a kirocrew config get taskrunner.max_parallel_steps
docker exec kiro-a kirocrew config get mcp_gateway.max_backends
docker exec kiro-a kirocrew config get knowledge.max_sources
docker exec kiro-a kirocrew config get knowledge.extraction_pool_size
docker exec kiro-a kirocrew config get knowledge.folder_ingest_chunk_budget
```

Values can be changed in `.env` and reapplied with `make configure`. Lowering `knowledge.extraction_pool_size` or `knowledge.folder_ingest_chunk_budget` reduces maximum indexing speed, but prevents a large source from blocking ACP chat. Increasing Docker memory is unnecessary while the host has available memory; first limit concurrency and process sources in batches.

The `Request initialize timed out after 30s` error occurs during the ACP handshake, before the message is processed. The local runtime built by `Dockerfile.kirocrew` raises that budget to `KIROCREW_ACP_INIT_TIMEOUT_SECS` (120 seconds by default) and applies it at the `initialize` call site (see ADR-006 and ADR-008). Do not confuse it with `chat_turn_timeout_secs`, which controls turn duration after the session initializes.

```bash
docker exec kiro-a kirocrew config get agent.session_start_timeout_secs
docker inspect kiro-a kiro-b --format '{{.Name}} {{range .Config.Env}}{{println .}}{{end}}' | grep KIROCREW_ACP_INIT_TIMEOUT_SECS
```

If the message shows the configured value (e.g. `timed out after 240s`), the handshake is genuinely taking that long. In reference measurements with an idle host, `initialize` responds in ~2s and Kiro Crew MCPs in ~1s, so a timeout at the full budget almost always indicates host contention, not the project path or Knowledge. Recommended diagnosis:

```bash
docker stats --no-stream
docker logs kiro-a --since 30m 2>&1 | Select-String "MCP probe failed|timed out"
```

If other containers continuously consume CPU, limit them instead of stopping them (`docker update --cpus 1.0 <container>`). As an additional optimization, `PROJECTS_BASE` performs better on a native WSL2 path than on a Windows bind mount (`C:\...`); it is not required, but reduces I/O latency with many small files.

## Project tree masking

Traversing directories on a Windows bind mount costs ~1 ms per entry. A repository with a large `node_modules` turns any tree traversal into a minutes-long operation that leaves the gateway without an event loop, and the symptom is `Request initialize timed out`. In `example-org/sample-repo`, the complete traversal was 58 213 files in 64.1 s, of which `node_modules` contributed 53 039 files and 57.1 s.

`make masks` scans `PROJECTS_BASE` and generates `docker-compose.override.yml`, mounting an empty `tmpfs` over each dependency or cache directory, so the container cannot see them and no traversal descends into them. With masks active, that same traversal drops to 2 471 files in 6.3 s. See ADR-009.

```bash
make masks                                              # regenerate the override
make mask-report PROJECT=example-org/sample-repo   # measure the tree
```

`up`, `restart`, and `update` chain `masks`, so the override never becomes stale. After cloning a repository or installing dependencies on the host, run `make masks` to create the corresponding mask.

The list is controlled by `KIROCREW_MASK_DIRS` in `.env`. `.git`, `build`, and `dist` are intentionally left visible because their cost is marginal and the agent needs them. Masked directories appear **empty** inside the container: if a workflow needs the real dependencies, remove that name from the list and regenerate. An `npm install` inside the container writes to the `tmpfs` (`KIROCREW_MASK_TMPFS_SIZE`, 1 GB by default) and is not shared with Windows or preserved across restarts.

`docker-compose.override.yml` is a generated, host-specific file; it is in `.gitignore` and must not be edited manually.

## SSH and GCP IAP

The runtime image includes the OpenSSH client (`openssh-client`) in both Kiro containers. This enables `gcloud compute ssh`, including IAP-tunneled connections, from ACP shells without running an SSH server inside KiroCrew.

Verify the client and the Google Cloud SSH command surface with:

```bash
make ssh-test
# Or target one instance:
make ssh-test INSTANCE=kiro-b
```

Example:

```bash
gcloud compute ssh VM_NAME \
  --zone ZONE \
  --project PROJECT_ID \
  --tunnel-through-iap \
  --command 'COMMAND'
```

The remote VM must allow the authenticated GCP identity to connect and the IAP/SSH prerequisites must be configured in Google Cloud. Do not place passwords, private keys, or command output containing secrets in Git or documentation.

## GitHub identity per instance

Each instance authenticates with its own GitHub account (ADR-010). Configure the PATs in `.env`:

```dotenv
GH_USER_A=your-gh-user-a
GH_TOKEN_A=your-token-a
GH_USER_B=your-gh-user-b
GH_TOKEN_B=your-token-b

# Optional:
#GH_EMAIL_A=...   # default: <GH_USER_A>@users.noreply.github.com
#GH_EMAIL_B=...
```

At startup, `kiro-a-config` and `kiro-b-config` write `~/.gitconfig` in the persistent volume with `user.name`, `user.email`, and the credential helper for `gh`. `gh` does not require `gh auth login`: it reads `GH_TOKEN` on every invocation, so nothing is lost on restart.

```bash
make gh-identity    # verifies both accounts
make gh-test        # details version, auth, login, git name/email
```

Important:

- PATs must **never** go into Git; `.env` and `docker-compose.override.yml` are in `.gitignore`.
- Each instance pushes as its own account. Make sure the remote repository uses HTTPS (`https://github.com/...`) to use the `gh` helper.
- If a token expires, change it in `.env` and restart the corresponding container.

## Node.js inside KiroCrew

Node.js 22, npm, npx, and corepack are injected through the `node-cli` init service, without installing Node.js on the host:

```bash
docker compose run --rm make node-test
docker exec kiro-a bash -l -c 'node --version && npm --version && npx --version'
```

The `node-bin` volume is a tool cache; recreate it with `docker compose up -d --force-recreate` if you change the sidecar version or contents. The Dockerized Make service prioritizes variables received from Compose over `.env` values, to preserve host paths correctly when running nested Compose.

## Persistence and backup

The `kiro-a-home` and `kiro-b-home` volumes contain, respectively, the memory, configuration, credentials, and history of Kiro A and Kiro B. Both persist across recreations.

Do not run `docker volume rm kiro-a-home kiro-b-home` or `docker compose down -v` without a backup. To create backups for both instances:

```bash
make backup
```

You can also run the equivalent through the Dockerized Make service:

```bash
docker compose run --rm make backup
```

## Troubleshooting

### Docker socket or permissions

Confirm that Docker Desktop is active and WSL2 integration is enabled:

```bash
docker version
docker compose version
ls -l /var/run/docker.sock
```

If the socket exists but `docker ps` fails inside the container, check its GID and configure it in `.env`:

```bash
stat -c '%g' /var/run/docker.sock
# Update DOCKER_SOCKET_GID in .env with that value
docker compose logs docker-cli
docker compose up -d --force-recreate
```

On Docker Desktop + WSL2, the socket normally appears as `root:root`, so `DOCKER_SOCKET_GID=0` is expected. KiroCrew continues to run as the internal `kirocrew` user; `group_add` only adds the supplementary group needed to access the socket.

### Project paths

Check that the configured directory exists from WSL2:

```bash
set -a
source .env
set +a
ls -la "$PROJECTS_BASE"
```

If you edited `.env`, recreate the service to apply the mount:

```bash
docker compose up -d --force-recreate kiro-a kiro-b
```

### Corrupt volume or inconsistent state

First make the backup described above. Remove or restore the volume only after confirming that the copy is valid. Persistent state is not erased by a normal `docker compose down`.

### Chromium / Playwright

The image installs `ffmpeg`, `libreoffice` (including Impress and Draw), Chromium runtime libraries, and `@playwright/cli` 0.1.18 for both agents. The `node-cli` sidecar downloads Chromium into the persistent `playwright-browsers` volume, and each instance registers skills at `/home/kirocrew/.agents/skills/playwright-cli`.

The wrapper selects Chromium automatically when running `playwright-cli open`; you can also specify it explicitly:

```bash
docker compose exec kiro-a playwright-cli open http://host.docker.internal:3000
docker compose exec kiro-b playwright-cli open http://host.docker.internal:3000 --browser=chromium
```

`SYS_ADMIN` is included because the Chromium sandbox requires it. If browser mode fails, check that no external configuration removed the capability and consult the KiroCrew logs.

For PPTX Maker, LibreOffice runs headless inside both containers to generate thumbnails and PDF previews:

```bash
docker compose exec kiro-a libreoffice --headless --version
docker compose exec kiro-b libreoffice --headless --version
```

## Structure

```text
.
├── docker-compose.yml
├── compose/
│   ├── shared.yml
│   ├── kiro-a.yml
│   └── kiro-b.yml
├── Dockerfile.make
├── .dockerignore
├── .env.example
├── Makefile
├── projects/.gitkeep
├── scripts/
│   ├── add-project.sh
│   └── generate-mask-override.sh
├── tests/validate.sh
├── .github/workflows/validate.yml
└── docs/
    ├── README.md
    ├── en/
    ├── es/
    └── architecture/
        ├── kiro-crew-architecture.html
        ├── kiro-crew-architecture.json
        ├── kiro-crew-workflow.html
        ├── kiro-crew-workflow.json
        ├── kiro-crew-sequence.html
        ├── kiro-crew-sequence.json
        ├── kiro-crew-dataflow.html
        └── kiro-crew-dataflow.json
```

## License

This project is distributed under the MIT license. See [`LICENSE`](../../LICENSE).

## Contributing

Public configurations must use placeholders and remain free of personal paths, private project names, and credentials. Use `.env` for your local values; it is excluded from Git. Before opening a PR, run:

```bash
./tests/validate.sh
docker compose --profile tools build make
git diff --check
```

Validation does not start KiroCrew or require credentials. Full runtime validation requires Docker Desktop/WSL2 and should be run by following the quick setup.
