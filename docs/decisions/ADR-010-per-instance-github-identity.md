# ADR-010: Identidad de GitHub por instancia

## Status

Accepted (2026-08-18).

## Context

Kiro Crew corre dos instancias: `kiro-a` y `kiro-b`. Originalmente compartían un
único `GH_TOKEN`, lo que forzaba a una misma cuenta de GitHub para ambas y
perdía el sentido de separar instancias por cliente/cuenta. El usuario necesita:

- `kiro-a` autenticado como `Jerson-Martinez-JEM0925`.
- `kiro-b` autenticado como `jersonmartinez`.

Además, el agente dentro del contenedor debe poder ejecutar `gh` y `git`
operaciones sin una configuración manual que se repita en cada reinicio.

La inspección de `kiro_crew/sandbox.py` muestra que `GH_TOKEN` no está en
`_AGENT_DENIED_ENV_KEYS` ni en `_SENSITIVE_ENV_PREFIXES`, por lo que puede
heredarse a los subprocesos del agente. Sí está `GIT_ASKPASS`, así que ese
mecanismo de credenciales no es viable para `git`.

`gh auth git-credential` responde a `git` usando el `GH_TOKEN` del entorno,
pero requiere que el helper de credenciales esté configurado en `~/.gitconfig`.

## Decision

1. Cada servicio recibe su propio par de variables:
   - `GH_USER_A` / `GH_TOKEN_A` para `kiro-a`.
   - `GH_USER_B` / `GH_TOKEN_B` para `kiro-b`.
2. Los servicios `kiro-a-config` y `kiro-b-config` escriben
   `~/.gitconfig` en el volumen persistente de cada instancia antes de iniciar:
   - `user.name` y `user.email` desde `GH_USER_*` (con
     `@users.noreply.github.com` por defecto).
   - `credential."https://github.com".helper` apuntando a
     `/opt/gh-cli/gh auth git-credential`.
   - `safe.directory '*'` para evitar errores de propiedad sobre bind mounts.
3. `gh` no requiere `gh auth login`: lee `GH_TOKEN` y `GH_HOST` de la variable
   en cada invocación, así que la identidad sobrevive a los reinicios sin
   intervención manual.
4. Se añaden targets `gh-test` y `gh-identity` en el `Makefile` para verificar
   ambas cuentas en segundos.

## Alternatives Considered

### Ejecutar `gh auth login` una vez dentro de cada contenedor

Rechazado: el estado de autenticación (`~/.config/gh/hosts.yml`) no se garantiza
que persista sin volúmenes adicionales, y requeriría interacción manual en cada
recreación.

### Usar `GIT_ASKPASS` con un script

Rechazado: `GIT_ASKPASS` es un prefijo sensible y kiro-crew lo retira del
entorno del agente. No es confiable.

### Volumen compartido para credenciales de `gh`

Rechazado: compartiría identidad entre `kiro-a` y `kiro-b`, contradiciendo el
requisito.

### SSH keys en `.ssh`

Rechazado: los proyectos usan HTTPS por defecto y exigiría claves por cuenta
con montajes adicionales. HTTPS con token mantiene el mismo modelo que el
Compose actual.

## Consequences

- Cada instancia tiene cuenta de GitHub aislada; no hay conflictos de commits
  entre `kiro-a` y `kiro-b`.
- Los PATS siguen en `.env` (`.gitignore`) y no aparecen en el repositorio.
- Si un token expira, solo hay que actualizar `.env` y reiniciar; no se
  requiere `gh auth login`.
- `git push` y `gh` funcionan directamente desde el agente, siempre que el
  repositorio de destino sea accesible por la cuenta que corresponda a la
  instancia.
- Los noreply emails evitan filtrar direcciones personales en el histórico.
