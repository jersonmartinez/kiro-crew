# ADR-001: Inyectar Docker CLI mediante un servicio init

## Status
Accepted

## Context
La imagen base de KiroCrew incluye Python, Git y curl, pero no incluye Docker CLI. KiroCrew necesita ejecutar `docker compose` en los proyectos montados. El entorno objetivo es un bootstrap público para desarrollo local sobre Docker Desktop y WSL2.

## Decision
Usar un servicio `docker-cli` basado en `docker:cli`. El servicio copia el cliente Docker y el plugin Compose a un named volume `docker-bin`; `kirocrew` consume ese volumen en `/opt/docker-cli` y en la ruta estándar de plugins. `depends_on` espera que el servicio de copia finalice correctamente antes de iniciar KiroCrew.

## Alternatives Considered

### Dockerfile extendido
Habría producido una imagen más autocontenida, pero añade un ciclo de build y mantenimiento de paquetes que no es necesario para este entorno local.

### Montar el volumen en `/usr/local/bin`
Se descartó porque un montaje sobre el directorio completo puede ocultar binarios existentes de la imagen base. El CLI se expone en una ruta dedicada mediante `PATH`.

## Consequences
- `docker compose up -d` es idempotente después del setup inicial y no requiere una imagen personalizada.
- El servicio KiroCrew deja que el Tini incluido en la imagen sea PID 1 para recoger procesos ACP/MCP correctamente.
- El volumen `docker-bin` se recrea/actualiza al ejecutar el servicio init.
- El socket Docker sigue siendo root-equivalente en el host y se acepta únicamente para desarrollo local.
- La compatibilidad del CLI sigue la arquitectura de la imagen oficial `docker:cli` usada por Docker Desktop.
