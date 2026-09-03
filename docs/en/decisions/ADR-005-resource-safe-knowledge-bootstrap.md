# ADR-005: Apply safe Knowledge limits during bootstrap

## Status
Accepted

## Context

KiroCrew shares the ACP gateway with the Knowledge indexer. A large local source can start several extraction jobs and ACP processes simultaneously. On Docker Desktop + WSL2, the container had no CPU, memory, or process limits, but concurrency could saturate the event loop and produce `Request initialize timed out` while the host still had memory available.

Local measurement showed approximately 435% CPU, 4.8 GiB RAM, and 416 processes during concurrent indexing. After pausing active sources, usage fell to approximately 173% CPU, 739 MiB RAM, and 32 processes without changing Docker resources.

## Decision

Add the idempotent `kirocrew-config` service to Compose. Before starting `kirocrew`, it writes these safe Knowledge values to the persistent volume:

- `knowledge.max_sources=100`
- `knowledge.extraction_pool_size=1`
- `knowledge.folder_ingest_chunk_budget=25`

Defaults live in `compose/kiro-a.yml` and `compose/kiro-b.yml` and can be overridden from `.env` through `KIROCREW_KNOWLEDGE_*`. `make configure` reapplies them without removing the volume. Large-source indexing must be processed in batches rather than confirmed massively in parallel. This reduces maximum throughput to preserve ACP chat capacity.

## Alternatives Considered

### Increase Docker memory or CPU

Rejected as the first measure. The environment had 16 CPUs, 31 GiB assigned, and more than 20 GiB available; the observed bottleneck was concurrency and event-loop pressure, not memory limits or an OOM kill.

### Set strict Docker service limits

Deferred. A hard limit could turn legitimate indexing into an OOM kill and hide scheduling problems. Application-level pools and budgets are controlled first.

### Leave configuration only in the manually managed volume

Rejected because a new installation would not inherit the values and the issue would return in another environment.

## Consequences

- New installations apply reproducible defaults before starting the gateway.
- Recreation does not delete sessions, memory, credentials, or sources; volumes `kiro-a-home` / `kiro-b-home` persist.
- Bulk indexing takes longer, but chat and ACP remain responsive.
- Operators may gradually increase values from `.env` after measuring CPU, RAM, processes, and ACP latency.
- Paused sources do not resume automatically and must be deliberately processed in batches.
