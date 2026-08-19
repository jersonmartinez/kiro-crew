# ADR-006: Hacer configurable el presupuesto del handshake ACP

## Status
Accepted. Emendado por ADR-008 (el parche del call site hace efectivo el
presupuesto; ADR-006 por sí solo dejaba la constante sin referencias).

## Context

Kiro Crew usaba un timeout fijo de 30 segundos para la petición ACP
`initialize`. Ese límite se alcanza antes de procesar el mensaje del usuario y es
distinto de `chat_turn_timeout_secs` y de `agent.session_start_timeout_secs`.

El agente completo carga MCPs durante el arranque. En un entorno Docker con
Knowledge indexando fuentes locales, el handshake puede superar 30 segundos sin
que el turno del usuario sea realmente lento. El síntoma visible era:
`Request initialize timed out after 30s`.

## Decision

Construir una imagen local derivada de la imagen base configurada mediante
`Dockerfile.kirocrew`. El Dockerfile sustituye el valor fijo del runtime ACP por
la variable `KIROCREW_ACP_INIT_TIMEOUT_SECS`, cuyo valor por defecto es 120
segundos. Compose inyecta la misma variable en el gateway para que el valor sea
visible y verificable en ejecución.

El parche se reconstruye cuando cambia la imagen base con `make update`, y los
volúmenes `kiro-a-home` / `kiro-b-home` se conservan sin modificaciones
destructivas.

## Alternatives Considered

### Aumentar `chat_turn_timeout_secs`

Rechazado: ese timeout empieza después del handshake y no afecta `initialize`.

### Aumentar `agent.session_start_timeout_secs`

Rechazado como solución única: aplica a `session/new` y `session/load`, pero no a
la petición ACP `initialize` que estaba expirando a los 30 segundos.

### Desactivar MCPs o usar siempre `kirocrew-lite`

Se conserva como fallback operativo cuando un MCP no responde, pero no es la
solución predeterminada porque elimina capacidades del agente completo.

### Aumentar indiscriminadamente CPU/RAM

Rechazado como primera medida: la medición mostró disponibilidad de recursos,
pero una alta concurrencia de ACP/Knowledge. El ajuste de timeout permite esperar
arranques legítimamente lentos sin ocultar el control de concurrencia.

## Consequences

- Un MCP realmente muerto puede tardar hasta 120 segundos en fallar, en vez de 30.
- Los usuarios pueden reducir o aumentar el valor desde `.env` sin modificar el
  código de Kiro Crew.
- El timeout no corrige un MCP que nunca responde; esos servidores deben seguir
  monitorizándose y pueden requerir pausa o reparación.
- El runtime local debe reconstruirse al cambiar `KIROCREW_IMAGE`.
