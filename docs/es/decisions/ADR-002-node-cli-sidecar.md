# ADR-002: CLI de Node.js mediante un sidecar init

## Status

Accepted

## Context

KiroCrew trabaja con frecuencia en proyectos JavaScript/TypeScript (Next.js, React, Vite). Sin Node.js, el agente no puede ejecutar `npm run lint`, `npx vitest`, `tsc --noEmit` ni otras validaciones, obligando al usuario a ejecutarlas manualmente y pegar el resultado.

La imagen base incluye Python y herramientas CLI comunes, pero omite deliberadamente los runtimes de lenguajes para mantenerla mínima.

## Decision

Inyectar Node.js 22 usando el mismo patrón de sidecar que `docker-cli` (ADR-001):

1. Un servicio init `node-cli` basado en `node:22-slim` copia `node` y el árbol de módulos globales al volumen `node-bin`, y recrea allí los enlaces simbólicos lanzadores de `npm`, `npx` y `corepack`.
2. El servicio `kirocrew` monta `node-bin` en `/opt/node-cli:ro`.
3. `PATH` incluye `/opt/node-cli/bin`.
4. `NODE_PATH` se establece en `/opt/node-cli/lib/node_modules` para resolver módulos globales.

## Consequences

- Node.js está disponible sin reconstruir la imagen de KiroCrew.
- Actualizar Node requiere cambiar el tag en `compose/shared.yml` (por ejemplo, `node:22-slim`).
- Los `node_modules` de cada proyecto permanecen dentro del directorio del proyecto (bind-mounted).
- El sidecar añade aproximadamente 2 s al primer `docker compose up`, pero queda en caché en los siguientes arranques.

## Alternatives Considered

- **Dockerfile extendido:** aumenta el mantenimiento y se desacopla de las actualizaciones upstream.
- **Entrar en un contenedor Node:** impide que KiroCrew ejecute comandos npm nativamente desde su propio shell y complica la automatización.
