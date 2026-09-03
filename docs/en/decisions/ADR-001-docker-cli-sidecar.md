# ADR-001: Inject Docker CLI through an init service

## Status

Accepted

## Context

The KiroCrew base image includes Python, Git, and curl, but not Docker CLI. KiroCrew must run `docker compose` in mounted projects. The target environment is a public bootstrap for local development on Docker Desktop and WSL2.

## Decision

Use a `docker-cli` service based on `docker:cli`. The service copies the Docker client and Compose plugin into the named volume `docker-bin`; `kirocrew` consumes this volume at `/opt/docker-cli` and in the standard plugin path. `depends_on` waits for the copy service to finish successfully before starting KiroCrew.

## Alternatives Considered

### Extended Dockerfile

This would produce a more self-contained image, but adds a package build and maintenance cycle unnecessary for this local environment.

### Mount the volume at `/usr/local/bin`

Rejected because mounting the entire directory could hide existing image binaries. The CLI is exposed at a dedicated path through `PATH`.

## Consequences

- `docker compose up -d` is idempotent after initial setup and requires no custom image.
- The KiroCrew service lets the Tini included in the image remain PID 1 so ACP/MCP processes are reaped correctly.
- The `docker-bin` volume is recreated/updated when the init service runs.
- The Docker socket remains root-equivalent on the host and is accepted only for local development.
- CLI compatibility follows the architecture of the official `docker:cli` image used by Docker Desktop.
