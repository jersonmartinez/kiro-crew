# ADR-004: GitHub CLI mediante un sidecar init

## Status
Accepted

## Context

KiroCrew necesita inspeccionar repositorios e incidencias de GitHub desde dentro de su contenedor. La imagen base no incluye la CLI `gh`, e instalar herramientas en el host haría el bootstrap menos reproducible.

## Decision

Usar un servicio init `gh-cli` basado en `debian:trixie-slim`. Instala el paquete Debian `gh`, copia `/usr/bin/gh` al volumen con nombre `gh-bin`, y el servicio `kirocrew` monta ese volumen en modo solo lectura en `/opt/gh-cli`.

La autenticación se proporciona únicamente mediante la variable de entorno local e ignorada `GH_TOKEN`. El token no se escribe en la imagen, el archivo Compose ni `.env.example`.

## Consequences

- `gh` está disponible dentro de KiroCrew sin instalarlo en el host.
- Actualizar el paquete Debian requiere volver a ejecutar el servicio init.
- El token de GitHub concede los scopes/permisos configurados por el usuario; debe tratarse como secreto y rotarse si se expone.
- El servicio Make Dockerizado puede verificar `gh` con `make gh-test`.
