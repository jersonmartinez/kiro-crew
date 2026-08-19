# ADR-008: Aplicar el timeout de initialize en el call site del handshake ACP

## Status

Accepted (2026-08-18). Emienda ADR-006.

## Context

ADR-006 hizo configurable el presupuesto del handshake ACP sustituyendo la
constante `_INIT_TIMEOUT = 30.0` del runtime por una lectura de
`KIROCREW_ACP_INIT_TIMEOUT_SECS`. En la práctica el error seguía apareciendo
como `Request initialize timed out after 30s` aun con la variable en 120.

La inspección del runtime parcheado mostró que `_INIT_TIMEOUT` quedaba definida
pero **sin ninguna referencia**: la petición `initialize` llama a
`_send_and_await("initialize", {...})` sin argumento `timeout`, cayendo en el
default `_REQUEST_TIMEOUT = 30.0`
(`kiro_crew/acp/runtime.py`, `AcpRuntime.spawn`). El mensaje de error usa el
timeout efectivo (`timed out after {timeout:g}s`), por lo que "30s" delataba que
el presupuesto configurado nunca se aplicaba.

Además, una vez aplicado el presupuesto real (120s), se observaron timeouts
intermitentes de 120s agrupados en ventanas donde también fallaban los probes
MCP de `kirocrew-core`/`kirocrew-cron` (15s). Las mediciones directas con el
host despejado mostraron `initialize` en ~2s y los MCP en ~1s, por lo que la
causa raíz era **contención de CPU/I/O del host** (otros contenedores al 90% de
CPU, bind-mount de Windows vía Docker Desktop), no la longitud de la ruta del
proyecto ni la indexación de Knowledge.

## Decision

1. `Dockerfile.kirocrew` aplica un segundo parche que pasa
   `timeout=_INIT_TIMEOUT` en el call site de `initialize`. Ambos parches
   fallan el build (`SystemExit`) si el texto esperado no existe en la imagen
   base, de modo que un cambio upstream rompe ruidosamente en vez de degradar
   en silencio.
2. Elevar el valor operativo a `KIROCREW_ACP_INIT_TIMEOUT_SECS=240` en `.env`
   como red de seguridad para hosts con carga concurrente.
3. Mitigar la contención del host limitando CPU de contenedores ajenos
   (`docker update --cpus 1.0 <contenedor>`) en vez de detenerlos.

## Alternatives Considered

### Subir `_REQUEST_TIMEOUT` global

Rechazado: `_REQUEST_TIMEOUT` es el presupuesto del plano de control genérico;
elevarlo haría lentos de detectar todos los requests colgados, no solo el
handshake.

### Migrar `PROJECTS_BASE` a una ruta nativa WSL2

Evaluado y diferido: `PROJECTS_BASE` ocupaba 18.17 GB; duplicarlo en el VHDX de
la distro es costoso. Queda como optimización opcional documentada en el README
(las rutas nativas de WSL2 rinden mejor que los bind-mounts de Windows en I/O de
muchos archivos pequeños).

### Depender solo del aumento de timeout

Rechazado: sin mitigar la contención, los picos de carga seguirían produciendo
arranques de minutos; el timeout alto es red de seguridad, no solución.

## Consequences

- El mensaje de error ahora refleja el valor configurado (p.ej. `240s`); un
  timeout con el valor configurado indica lentitud real y amerita revisar
  `docker stats` y los probes MCP.
- Un kiro-cli realmente colgado puede tardar hasta 240s en fallar.
- Al actualizar `KIROCREW_IMAGE`, el build valida que ambos parches sigan
  aplicando; si upstream ya pasa `timeout=_INIT_TIMEOUT`, el segundo parche
  fallará el build y deberá retirarse.
