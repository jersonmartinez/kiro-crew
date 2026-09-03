# ADR-007: Ejecutar dos instancias aisladas de Kiro Crew

## Status
Accepted

## Context

Se necesita ejecutar dos gateways de Kiro Crew en el mismo host Docker, cada uno
con una cuenta distinta de Kiro autenticada mediante IAM Identity Center.

Una sola instancia no puede compartir de forma segura el estado de autenticación,
la memoria, las conversaciones y la configuración de la otra. Además, Docker
Desktop/WSL2 bloquea el sandbox Linux anidado de Kiro Crew si se conserva la
política seccomp/AppArmor predeterminada.

## Decision

Definir dos servicios explícitos en Compose:

- `kiro-a`, publicado en `127.0.0.1:5476`.
- `kiro-b`, publicado en `127.0.0.1:5477`.

Cada servicio usa un volumen independiente (`kiro-a-home` y `kiro-b-home`) y
expone `KIRO_HOME` y `KIROCREW_HOME` dentro de ese volumen. Sus servicios init
(`kiro-a-config` y `kiro-b-config`) ejecutan automáticamente el bootstrap de
Kiro CLI, regeneran los agent specs y marcan el setup como completado cuando
`kiro-cli whoami` confirma una sesión válida.

La autenticación interactiva no se automatiza: cada cuenta debe iniciar sesión
una vez con `kiro-cli login`. El estado queda persistido en el volumen de su
instancia.

Para permitir el sandbox anidado necesario en Docker Desktop/WSL2, ambas
instancias usan `seccomp:unconfined` y `apparmor:unconfined`. Los dashboards
continúan publicados exclusivamente en localhost y el socket Docker conserva
el acceso necesario para el flujo de desarrollo.

## Alternatives Considered

### Compartir un único volumen

Rechazado: mezclaría credenciales, memoria y sesiones de dos cuentas.

### Usar únicamente `--profile` de Compose

Rechazado: los perfiles de Compose seleccionan servicios, pero no aíslan el
estado persistente ni las credenciales.

### Conservar el sandbox seccomp/AppArmor predeterminado

Rechazado para este entorno: el probe de Kiro Crew no puede completar el mount
namespace anidado y el dashboard permanece bloqueado en el setup de Kiro CLI.

### Automatizar OAuth

Rechazado: el login requiere interacción del propietario con IAM Identity
Center y no debe simularse ni guardar credenciales en el repositorio.

## Consequences

- `docker compose up -d` inicia y configura ambas instancias.
- La primera autenticación de cada cuenta sigue siendo interactiva.
- Cada cuenta conserva sus credenciales y datos de forma independiente.
- El bootstrap vuelve a instalar Kiro CLI si el binario de usuario no existe.
- La superficie de aislamiento del contenedor es menor por `seccomp:unconfined`
  y `apparmor:unconfined`; no se deben publicar los dashboards fuera de localhost.
- Los volúmenes `kiro-a-home` y `kiro-b-home` deben incluirse en backups.
