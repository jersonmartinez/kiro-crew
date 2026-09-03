# ADR-005: Aplicar límites seguros de Knowledge durante el bootstrap

## Status
Accepted

## Context

KiroCrew comparte el gateway ACP con el indexador de Knowledge. Una fuente local grande puede iniciar varios trabajos de extracción y procesos ACP simultáneos. En Docker Desktop + WSL2, el contenedor no tenía límites propios de CPU, memoria o procesos, pero la concurrencia podía saturar el event loop y producir `Request initialize timed out` aunque el host todavía tuviera memoria disponible.

La medición local mostró aproximadamente 435% de CPU, 4.8 GiB de RAM y 416 procesos durante una indexación concurrente. Después de pausar fuentes activas, el consumo bajó a aproximadamente 173% de CPU, 739 MiB de RAM y 32 procesos, sin cambiar los recursos asignados a Docker.

## Decision

Añadir el servicio idempotente `kirocrew-config` al Compose. Antes de iniciar `kirocrew`, escribe en el volumen persistente los valores seguros de Knowledge:

- `knowledge.max_sources=100`
- `knowledge.extraction_pool_size=1`
- `knowledge.folder_ingest_chunk_budget=25`

Los valores tienen defaults en `compose/kiro-a.yml` y `compose/kiro-b.yml` y pueden sobrescribirse desde `.env` mediante las variables `KIROCREW_KNOWLEDGE_*`. El target `make configure` permite reaplicarlos sin eliminar el volumen.

La indexación de fuentes grandes debe procesarse por lotes y no confirmarse masivamente en paralelo. El ajuste reduce el throughput máximo para preservar la capacidad de chat ACP.

## Alternatives Considered

### Aumentar memoria o CPU de Docker

Se descarta como primera medida. El entorno ya tenía 16 CPUs, 31 GiB asignados y más de 20 GiB disponibles durante el incidente. El cuello observado era la concurrencia y la presión del event loop, no un límite de memoria ni un OOM kill.

### Fijar límites Docker estrictos en el servicio

Se descarta por ahora. Un límite rígido podría convertir una carga legítima de indexación en un OOM kill y ocultar el problema de planificación. La configuración controla primero los pools y presupuestos a nivel de aplicación.

### Dejar la configuración solo en el volumen manual

Se descarta porque una instalación nueva no heredaría los valores y el problema reaparecería al levantar el proyecto en otro entorno.

## Consequences

- Las instalaciones nuevas aplican defaults reproducibles antes de iniciar el gateway.
- Las recreaciones no borran sesiones, memoria, credenciales ni fuentes porque los servicios usan volúmenes persistentes (`kiro-a-home` / `kiro-b-home`).
- La indexación masiva tarda más, pero el chat y ACP conservan capacidad de respuesta.
- Un operador puede aumentar gradualmente los valores desde `.env` después de medir CPU, RAM, procesos y latencia ACP.
- Las fuentes ya pausadas no se reanudan automáticamente; deben procesarse por lotes de forma deliberada.
