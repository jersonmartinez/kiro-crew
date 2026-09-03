# Seguridad y límites operativos

## Modelo de confianza

Este proyecto está diseñado para desarrollo local. KiroCrew puede leer y modificar los proyectos montados, ejecutar procesos dentro de su contenedor y comunicarse con el Docker Engine mediante `/var/run/docker.sock`.

El socket Docker equivale en la práctica a acceso administrativo sobre el Engine del host. No expongas los dashboards fuera de localhost ni uses este Compose como servicio multiusuario o público sin una revisión adicional de aislamiento.

## Configuración predeterminada

- Los dashboards se publican únicamente en `127.0.0.1`.
- KiroCrew se ejecuta como el usuario no-root `kirocrew`.
- No se usa `privileged: true`.
- `SYS_ADMIN`, `seccomp:unconfined` y `apparmor:unconfined` se usan para el sandbox anidado de Chromium/Playwright en Docker Desktop/WSL2.
- El perfil `kirocrew-seccomp.json` no se activa automáticamente. Es experimental y debe validarse antes de usarlo.
- El árbol de proyectos tiene escritura porque el agente necesita modificar código. Usa montajes explícitos si necesitas reducir el alcance.

## Tokens de GitHub

`GH_TOKEN_A` y `GH_TOKEN_B` son opcionales. Solo configúralos si la instancia correspondiente debe usar GitHub CLI o hacer operaciones Git sobre HTTPS.

- Mantén los tokens exclusivamente en `.env` local o en un gestor de secretos.
- Usa tokens separados por instancia y con el menor alcance posible.
- Revoca y reemplaza un token si aparece en logs, historial, backups o archivos compartidos.
- Recuerda que el token se hereda a procesos hijos del agente cuando está configurado.

Los backups de los volúmenes contienen estado persistente y pueden contener credenciales. No los publiques ni los añadas al repositorio.

## Revisión antes de ampliar permisos

Antes de añadir puertos, montajes, capabilities, tokens o integraciones externas, actualiza un ADR y añade una prueba que demuestre el límite esperado. La validación estática no sustituye una prueba de runtime en Docker Desktop/WSL2.
