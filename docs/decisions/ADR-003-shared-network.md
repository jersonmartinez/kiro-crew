# ADR-003: Shared Network for Project Communication

## Status

Accepted

## Context

KiroCrew manages Docker Compose stacks for user projects. When those stacks run, their
containers live in an isolated network. KiroCrew needs to reach them
(for example, `curl http://project-app/health`) for health checks, API testing, and visual
verification via browser tools.

## Decision

Define a named managed network `kirocrew-net` in the KiroCrew compose file. Projects
that need reachability from KiroCrew declare the same network as external and attach
their relevant services to it while the KiroCrew stack is running.

KiroCrew compose:
```yaml
networks:
  kirocrew-net:
    name: kirocrew-net
    driver: bridge
```

Project compose example:
```yaml
networks:
  kirocrew-net:
    external: true

services:
  nginx:
    networks:
      - default
      - kirocrew-net
```

## Consequences

- KiroCrew can reach project services by container name without `host.docker.internal`.
- Projects remain isolated from each other unless they explicitly join the same network.
- The network is created by the KiroCrew Compose stack and can be reused by project stacks.
- If the network doesn't exist when a project starts, `docker compose up` will fail with
  a clear error — start KiroCrew first with `docker compose up -d`.
