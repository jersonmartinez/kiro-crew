# ADR-011: Modular Compose configuration with a central orchestrator

## Status
Accepted (2026-08-24).

## Context

Docker Compose configuration previously defined shared services, `kiro-a`, and `kiro-b` in one file. It worked but required reviewing a large definition to operate one instance. Both instances must remain selectable from one entry point while retaining service names, ports, dependencies, persistent volumes, and the generated host directory-mask override.

## Decision

1. Keep `docker-compose.yml` as the central entry point.
2. Use Compose `include` to load `compose/shared.yml` (sidecars, network, shared volumes), `compose/kiro-a.yml` (Kiro A config/service), and `compose/kiro-b.yml` (Kiro B config/service).
3. Retain service and volume names including `kiro-a-home` and `kiro-b-home`.
4. Retain `docker-compose.override.yml` as the host-generated override.
5. Expose individual operations through Makefile targets `up-a`, `up-b`, `shell-a`, `shell-b`, `logs-a`, and `logs-b`.

Compose `v5.3.1` in this environment supports `include`; environments need a modern Compose version with this capability. Relative paths resolve relative to each included file.

## Alternatives Considered

A single file with profiles does not separate definitions or reduce duplication. Merging with `-f` depends on file order and resolves paths against the first file, complicating build contexts and mounts. `extends` adds explicit declarations and unnecessary indirection; `include` better expresses application subdomains.

## Consequences

`docker compose up -d` remains central; individual instances can be started or inspected from the same entry point. Persistent volumes and container identities do not change. Included build paths use repository context via `context: ..`. Validate included files with `docker compose config` before recreating containers.
