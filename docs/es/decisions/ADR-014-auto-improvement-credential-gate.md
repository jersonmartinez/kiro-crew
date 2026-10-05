# ADR-014: Provisión de la puerta de credenciales de Auto-Improvement

## Estado

Aceptado

## Contexto

La app Auto-Improvement integrada en Kiro Crew mide un repositorio objetivo
antes de modificarlo: calibra una métrica, demuestra la regla y ejecuta ciclos
keep-or-revert que presentan los supervivientes como pull requests en
borrador. El trabajo lo realiza un equipo de agentes miembro respaldado por el
proveedor y desatendido, por lo que upstream se niega a construir el runner
mientras el sandbox efectivo del gateway esté por debajo de `strict`:

```text
AgentRunnerOffline: the run did no work because the provider-backed agent
runner was refused because the gateway sandbox is 'auto' — the
auto-improvement provider path requires a sandbox.min_level governance floor
of 'strict' (credential-hiding profile) or the explicit
acceptUnsandboxedAgentRisk opt-in
```

De otro modo, instrucciones controladas por el repositorio podrían alcanzar
los almacenes de credenciales en disco. Solo `strict` los oculta todos: `cc`
deja visibles las credenciales de SSH y de GitHub CLI, y `auto`/`standard`
además exponen las de AWS. `agent.sandbox` solo acepta `auto` u `off`, así que
`strict` no puede fijarse como preferencia de usuario; se alcanza mediante el
floor de gobernanza (`sandbox.min_level`) o se exime por app mediante
`acceptUnsandboxedAgentRisk`.

Ambas vías de desbloqueo existen upstream, pero nada las provisionaba: el
operador tenía que editar a mano archivos dentro del volumen persistente, algo
que `configure-instance.sh` ya existe para gestionar.

## Decisión

`configure-instance.sh` reconcilia dos variables de entorno en cada
`make up`/`make configure` (se pasan a los servicios `kiro-a-config` y
`kiro-b-config`):

- `KIROCREW_SANDBOX_MIN_LEVEL` (`off|standard|cc|strict`): siembra
  `~/.kiro/crew/security_policy.json` —el techo de gobernanza local, escrito
  por el operador— con `identity.issuer: kiro-crew-compose` y
  `sandbox.min_level` fijado al valor indicado. El floor eleva cada spawn de
  agente hasta el perfil `strict`, que oculta credenciales. El archivo se
  reconcilia como estado deseado: un archivo que el stack no generó (un
  `identity.issuer` distinto, o contenido no parseable) nunca se modifica; un
  archivo gestionado pierde `min_level` cuando la variable queda vacía y se
  elimina cuando no queda nada más. Los cambios aplican desde el siguiente
  arranque del gateway.
- `KIROCREW_AUTO_IMPROVEMENT_ACCEPT_UNSANDBOXED_RISK` (`0|1`): `1` fusiona
  `"acceptUnsandboxedAgentRisk": true` en
  `~/.kiro/crew/apps/auto-improvement/data/config.json`, preservando las claves
  que la app ya haya escrito. `0` elimina la clave. Un valor vacío deja el
  archivo intacto, de modo que un consentimiento otorgado desde el dashboard
  nunca se revoca en silencio. Aplica en la siguiente ejecución; el runner
  relee el archivo en cada run, así que no hace falta reiniciar.

Ambos valores se validan en `scripts/validation/validate-env.py` y quedan
fijados por `tests/validate.sh`.

## Alternativas consideradas

### Fijar `agent.sandbox` a `strict` directamente

Rechazado: `agent.sandbox` es un enum de `auto`/`off`; guardar `strict` se
carga como `auto` con una advertencia de violación de enum. Solo el floor de
gobernanza eleva el modo efectivo hasta `strict`.

### Hornear el opt-in en la imagen

Rechazado: `acceptUnsandboxedAgentRisk` y el techo de gobernanza son
consentimientos del operador. Escribirlos incondicionalmente en
`Dockerfile.kirocrew` concedería a un agente desatendido orientado al
repositorio acceso a los almacenes de credenciales sin que el operador tomara
esa decisión.

### Establecer `KIROCREW_SANDBOX_MIN_LEVEL=strict` por defecto

Rechazado: el perfil `strict` oculta `~/.kube`, `~/.aws`, `~/.azure`,
`~/.docker` y `~/.config/gh` de cada subproceso de agente en todo el gateway.
Este stack incluye kubectl y el plugin de autenticación de GKE
(ADR-012/ADR-013), así que activar `strict` por defecto rompería `kubectl`
desde los shells de agente en despliegues existentes en silencio. La puerta
permanece cerrada por defecto; el operador elige la vía.

## Consecuencias

- Auto-improvement funciona tras fijar una variable en `.env` y ejecutar
  `make configure` (consentimiento de riesgo) o `make restart` (floor de
  gobernanza).
- El floor `strict` cambia el acceso de los agentes a la config en disco de
  `kubectl`/`aws`/`az` por aislamiento real de credenciales; `gh` y git siguen
  funcionando vía `GH_TOKEN`, `gcloud` por la excepción de sandbox del
  ADR-012, y `~/.ssh` permanece visible.
- La vía del consentimiento de riesgo no cambia nada fuera de la app, pero los
  agentes miembro corren bajo `auto`, así que instrucciones influenciadas por
  el repositorio podrían leer archivos de credenciales presentes en el home de
  la instancia (`~/.kube`, `~/.ssh`).
- Una flota que más adelante adopte policy distribuida centralmente no se ve
  afectada: el archivo del tier home se apila debajo del documento central y
  un archivo no gestionado por el stack se deja intacto.
- La revocación funciona vaciando las variables (`0` para el consentimiento de
  la app); el stack elimina lo que escribió y deja los archivos ajenos
  intactos.
