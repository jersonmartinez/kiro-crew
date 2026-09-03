# ADR-008: Apply the initialize timeout at the ACP handshake call site

## Status
Accepted (2026-08-18). Amends ADR-006.

## Context

ADR-006 made the ACP handshake budget configurable by replacing runtime constant `_INIT_TIMEOUT = 30.0` with `KIROCREW_ACP_INIT_TIMEOUT_SECS`, but the error still reported `Request initialize timed out after 30s` when the variable was 120. The patched runtime defined `_INIT_TIMEOUT` with **no references**: `initialize` called `_send_and_await("initialize", {...})` without `timeout`, falling back to `_REQUEST_TIMEOUT = 30.0` (`kiro_crew/acp/runtime.py`, `AcpRuntime.spawn`). The error uses the effective timeout (`timed out after {timeout:g}s`).

After the real budget was applied, intermittent 120s timeouts coincided with failed MCP probes. Direct measurements on an idle host showed `initialize` in ~2s and MCPs in ~1s; the root cause was host CPU/I/O contention (other containers at 90% CPU and Windows bind mounts via Docker Desktop), not project path length or Knowledge indexing.

## Decision

1. `Dockerfile.kirocrew` applies a second patch passing `timeout=_INIT_TIMEOUT` at the `initialize` call site. Both patches fail the build (`SystemExit`) when expected text is absent, so upstream changes fail loudly.
2. Set operational `KIROCREW_ACP_INIT_TIMEOUT_SECS=240` in `.env` as a safeguard for concurrently loaded hosts.
3. Mitigate contention by limiting unrelated containers (`docker update --cpus 1.0 <container>`) rather than stopping them.

## Alternatives Considered

Raising global `_REQUEST_TIMEOUT` was rejected because it slows detection of every hung request. Moving `PROJECTS_BASE` to native WSL2 storage was evaluated and deferred because it occupied 18.17 GB. Relying only on a higher timeout was rejected: it is a safety net, not a remedy for contention.

## Consequences

- The error reflects the configured value (for example `240s`); reaching it indicates real slowness and warrants checking `docker stats` and MCP probes.
- A hung kiro-cli may take up to 240s to fail.
- Updating `KIROCREW_IMAGE` validates both patches; if upstream already passes `timeout=_INIT_TIMEOUT`, the second patch fails and must be removed.
