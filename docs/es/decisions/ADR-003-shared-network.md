# ADR-003: Red compartida para comunicación con proyectos

## Status

Accepted

## Context

KiroCrew administra stacks Docker Compose de proyectos. Cuando se ejecutan, sus contenedores viven en una red aislada. KiroCrew necesita alcanzarlos (por ejemplo, `curl http://project-app/health`) para health checks, pruebas de API y verificación visual mediante herramientas de navegador.

## Decision

Definir la red administrada con nombre `kirocrew-net` en el archivo Compose de KiroCrew. Los proyectos que necesiten ser accesibles desde KiroCrew declaran la misma red como externa y conectan a ella sus servicios relevantes mientras el stack de KiroCrew está activo.

Compose de KiroCrew:
```yaml
networks:
  kirocrew-net:
    name: kirocrew-net
    driver: bridge
```

Ejemplo de Compose del proyecto:
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

- KiroCrew puede alcanzar servicios de proyecto por nombre de contenedor sin `host.docker.internal`.
- Los proyectos permanecen aislados entre sí salvo que se unan explícitamente a la misma red.
- La red la crea el stack Compose de KiroCrew y puede reutilizarse desde stacks de proyectos.
- Si la red no existe al iniciar un proyecto, `docker compose up` falla con un error claro: primero hay que iniciar KiroCrew con `docker compose up -d`.
