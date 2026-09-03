# ADR-011: Configuración Compose modular con orquestador central

## Status

Accepted (2026-08-24).

## Context

La configuración de Docker Compose de KiroCrew definía servicios compartidos,
`kiro-a` y `kiro-b` en un solo archivo. Aunque ese archivo funcionaba, obligaba
a editar y revisar una definición extensa cuando solo se quería operar una
instancia.

Las dos instancias deben continuar siendo seleccionables desde un punto de
entrada único, conservar sus nombres de servicio, puertos, dependencias y
volúmenes persistentes, y seguir funcionando con el override generado que
aplica las máscaras de directorios del host.

## Decision

1. Mantener `docker-compose.yml` como punto de entrada central.
2. Usar la sección Compose `include` para cargar:
   - `compose/shared.yml`: sidecars, red y volúmenes compartidos.
   - `compose/kiro-a.yml`: configuración y servicio de Kiro A.
   - `compose/kiro-b.yml`: configuración y servicio de Kiro B.
3. Mantener los nombres actuales de servicios y volúmenes, incluyendo
   `kiro-a-home` y `kiro-b-home`.
4. Mantener `docker-compose.override.yml` como override generado por el host.
5. Exponer operaciones individuales mediante targets del `Makefile` como
   `up-a`, `up-b`, `shell-a`, `shell-b`, `logs-a` y `logs-b`.

La versión de Docker Compose instalada en este entorno (`v5.3.1`) soporta
`include`. La documentación oficial describe `include` como el mecanismo para
modularizar aplicaciones Compose y resolver las rutas relativas respecto de
cada archivo incluido. Los entornos deben usar una versión moderna de Compose
que incluya esta capacidad.

## Alternatives Considered

### Un único archivo con perfiles

Rechazado: los perfiles permiten seleccionar servicios, pero no separan las
definiciones de Kiro A y Kiro B ni reducen la duplicación del archivo.

### Múltiples archivos unidos con `-f`

Rechazado como opción principal: el merge depende del orden de los archivos y
las rutas relativas se resuelven respecto al primer archivo, lo que complica
los contextos de build y los bind mounts.

### `extends`

Rechazado: requiere declarar explícitamente los servicios extendidos y añade
indirección innecesaria para este caso. `include` expresa mejor que los
archivos representan subdominios de la misma aplicación Compose.

## Consequences

- `docker compose up -d` continúa siendo el comando central para iniciar ambas
  instancias.
- Es posible iniciar o inspeccionar Kiro A y Kiro B de forma individual desde
  el mismo punto de entrada.
- Los volúmenes persistentes y las identidades de los contenedores no cambian.
- Las rutas de build de los archivos incluidos usan el contexto del repositorio
  mediante `context: ..`.
- Requiere una versión moderna de Docker Compose con soporte para `include`.
- Los archivos incluidos deben validarse con `docker compose config` para
  detectar conflictos o errores de interpolación antes de recrear contenedores.
