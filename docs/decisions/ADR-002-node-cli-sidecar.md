# ADR-002: Node.js CLI via Init Sidecar

## Status

Accepted

## Context

KiroCrew frequently operates on JavaScript/TypeScript projects (Next.js, React, Vite).
Without Node.js, the agent cannot run `npm run lint`, `npx vitest`, `tsc --noEmit`, or
any other validation command — requiring the user to run them manually and paste output.

The KiroCrew base image ships Python and common CLI tools
but intentionally omits language runtimes to keep the image minimal.

## Decision

Inject Node.js 22 using the same sidecar pattern as `docker-cli` (ADR-001):

1. A `node-cli` init service based on `node:22-slim` copies `node` and the global module tree into a named volume `node-bin`, then recreates the `npm`, `npx`, and `corepack` launcher symlinks inside that volume.
2. The `kirocrew` service mounts `node-bin` at `/opt/node-cli:ro`.
3. `PATH` includes `/opt/node-cli/bin`.
4. `NODE_PATH` is set to `/opt/node-cli/lib/node_modules` for global module resolution.

## Consequences

- Node.js is available without rebuilding the KiroCrew image.
- Upgrading Node means changing the tag in `compose/shared.yml` (e.g., `node:22-slim`).
- Per-project `node_modules` still live inside the project directory (bind-mounted).
- The sidecar adds ~2s to first `docker compose up` but is cached on subsequent starts.

## Alternatives Considered

- **Extended Dockerfile:** Increases maintenance burden and decouples from upstream updates.
- **Exec into a Node container:** Breaks KiroCrew's ability to run npm commands natively
  from its own shell, complicating automation.
