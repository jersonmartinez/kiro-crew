# Implementation Plan: KiroCrew Docker Compose

## Overview
Crear un bootstrap público y reproducible para KiroCrew sobre Docker Desktop + WSL2, con estado persistente, proyectos configurables y acceso controlado al Docker Engine del host.

## Architecture Decisions
- Usar un servicio init `docker-cli` basado en `docker:cli` para copiar el binario y el plugin Compose a un named volume compartido.
- Montar el CLI en `/opt/docker-cli` y el directorio de plugins en la ruta estándar, evitando ocultar el resto de `/usr/local/bin` de la imagen KiroCrew.
- Mantener el dashboard publicado solo en `127.0.0.1`.
- Usar el named volume `kirocrew-home` como memoria y estado persistente del agente.

## Task List
- [x] Crear el Compose con persistencia, proyectos, socket, healthcheck y sidecar del CLI.
- [x] Parametrizar entorno y documentar el flujo de operación.
- [x] Eliminar rutas, nombres de proyectos y valores específicos del entorno del mantenedor.
- [x] Añadir Makefile y helper para proyectos adicionales.
- [x] Revisar seguridad, rutas WSL2 y comandos de validación.

## Verification Checkpoint
- `docker compose config` debe resolver el YAML sin errores.
- `.env` no debe aparecer en Git.
- El Compose debe conservar `kirocrew-home` y publicar únicamente `127.0.0.1:5476`.
- Si Docker Desktop está disponible, ejecutar `docker compose up -d` y `docker exec kirocrew docker ps`.

## Risks and Mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| Docker socket grants host-root-equivalent access | High | Documented as local-development-only and never expose the dashboard beyond localhost. |
| `/mnt/c` I/O latency | Medium | Document WSL2-native clone alternative. |
| Sidecar volume hides plugin path incorrectly | Medium | Mount CLI and plugin directory separately and verify with `docker compose version`. |
