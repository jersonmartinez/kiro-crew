# ADR-006: Make the ACP handshake budget configurable

## Status
Accepted. Amended by ADR-008 (the call-site patch makes the budget effective; ADR-006 alone left the constant unreferenced).

## Context

Kiro Crew used a fixed 30-second timeout for the ACP `initialize` request. This limit is reached before processing the user's message and differs from `chat_turn_timeout_secs` and `agent.session_start_timeout_secs`. The full agent loads MCPs at startup; with Knowledge indexing local sources, the handshake can exceed 30 seconds although the user turn is not slow. The visible symptom was `Request initialize timed out after 30s`.

## Decision

Build a local image derived from the configured base image using `Dockerfile.kirocrew`. The Dockerfile replaces the fixed ACP runtime value with `KIROCREW_ACP_INIT_TIMEOUT_SECS`, defaulting to 120 seconds. Compose injects the same variable into the gateway for runtime visibility and verification. `make update` rebuilds the patch when the base image changes, while `kiro-a-home` / `kiro-b-home` remain intact.

## Alternatives Considered

Increasing `chat_turn_timeout_secs` was rejected because it starts after the handshake. Increasing `agent.session_start_timeout_secs` alone was rejected because it covers `session/new` and `session/load`, not ACP `initialize`. Disabling MCPs or always using `kirocrew-lite` remains an operational fallback, not the default. Indiscriminately increasing CPU/RAM was rejected because measurements showed available resources but high ACP/Knowledge concurrency.

## Consequences

- A dead MCP may take up to 120 seconds to fail instead of 30.
- Users can change the value from `.env` without modifying Kiro Crew code.
- The timeout cannot fix an MCP that never responds; those servers still require monitoring, pausing, or repair.
- The local runtime must be rebuilt when `KIROCREW_IMAGE` changes.
