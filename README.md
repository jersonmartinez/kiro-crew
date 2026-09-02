# KiroCrew Docker Compose Bootstrap

Bootstrap público para ejecutar [KiroCrew](https://github.com/kirodotdev/kirocrew) con Docker Desktop y WSL2. Incluye persistencia para el estado del agente, Docker CLI + Compose dentro del contenedor, acceso configurable a proyectos de trabajo y un dashboard publicado únicamente en localhost.

La configuración no contiene rutas ni nombres de proyectos específicos de ningún entorno. El valor por defecto usa `./projects`; puedes cambiarlo en tu `.env` para reutilizar tus repositorios existentes.

## Qué incluye

- Imagen oficial de KiroCrew fijada por digest en `.env.example` para builds reproducibles.
- Servicio init `docker-cli` basado en `docker:cli`.
- Servicio init `node-cli` basado en `node:22-slim` (Node.js, npm, npx).
- Servicio init `gh-cli` basado en `debian:trixie-slim` (GitHub CLI).
- Docker CLI y el plugin Compose inyectados mediante el volumen `docker-bin`.
- Node.js CLI inyectado mediante el volumen `node-bin`.
- GitHub CLI inyectado mediante el volumen `gh-bin`.
- Docker CLI disponible también en shells interactivos/login mediante `/etc/profile.d`.
- Dos instancias aisladas: `kiro-a` y `kiro-b`.
- Estado persistente separado en los volúmenes `kiro-a-home` y `kiro-b-home`.
- Proyectos disponibles en `/home/kirocrew/projects/<nombre>` para ambas instancias.
- Dashboards en `http://localhost:5476` (Kiro A) y `http://localhost:5477` (Kiro B), sin exposición en interfaces externas.
- Capacidad `SYS_ADMIN` para el sandbox de Chromium/Playwright.
- Red compartida `kirocrew-net` para comunicación con stacks de proyectos.
- Makefile y helper para las operaciones habituales.
- Servicio opcional `make` para ejecutar Make dentro de Docker sin instalarlo en el host.

## Diagramas de arquitectura

Los diagramas interactivos generados con Archify se mantienen en [`docs/architecture/`](docs/architecture/):

- [Arquitectura](docs/architecture/kiro-crew-architecture.html)
- [Workflow de arranque, prompts y recuperación](docs/architecture/kiro-crew-workflow.html)
- [Secuencia Devin → Docker Desktop → WSL → Kiro Crew](docs/architecture/kiro-crew-sequence.html)
- [Dataflow de proyectos, mounts y configuración](docs/architecture/kiro-crew-dataflow.html)

Las especificaciones JSON y la evidencia de validación del navegador están junto a cada HTML. Los HTML son artefactos independientes: pueden abrirse localmente o servirse desde un servidor estático; GitHub puede mostrar el archivo como código en vez de ejecutar su contenido.

## Autenticación GCP dentro de ACP

`Dockerfile.kirocrew` conserva la configuración `gcloud` de cada instancia y permite que los shells ACP utilicen `/home/kirocrew/.config/gcloud`. El login debe realizarse por separado en cada volumen persistente (`kiro-a-home` y `kiro-b-home`):

```bash
docker compose exec -it kiro-a gcloud auth login
docker compose exec -it kiro-b gcloud auth login
docker compose exec kiro-b gcloud config set project PROJECT_ID
```

Las credenciales no se incluyen en la imagen, el repositorio ni los archivos `.env.example`; solo persisten en el volumen local de la instancia. Esta excepción permite acceso GCP desde el agente y, por ello, debe usarse únicamente con cuentas y permisos mínimos necesarios.

## Prerrequisitos

- Docker Desktop instalado y ejecutándose.
- Integración WSL2 habilitada para tu distribución Linux.
- WSL2 con `docker` y `docker compose` disponibles.
- Bash disponible en WSL2 para los scripts auxiliares.
- No es necesario instalar `make` en el host; el servicio `make` lo proporciona dentro de Docker.
- Un directorio para los proyectos que KiroCrew podrá leer y modificar.

El socket Docker otorga acceso equivalente a root sobre el Docker Engine del host. Por eso esta configuración está orientada a desarrollo local y no debe exponerse directamente a Internet.

### Modelo de privilegios

KiroCrew se ejecuta como el usuario no-root `kirocrew` (UID 1000). El Compose le concede únicamente los accesos necesarios para el flujo de desarrollo:

- `SYS_ADMIN` para el sandbox de Chromium/Playwright.
- El grupo del socket Docker mediante `DOCKER_SOCKET_GID`, para ejecutar Docker/Compose sin convertir el proceso en root.
- Montajes de proyectos y estado con escritura, necesarios para modificar código y conservar memoria.
- La red `kirocrew-net` para comunicarse con stacks de proyectos que se conecten explícitamente.

No se usa `privileged: true`, `sudo` ni `NET_ADMIN`. Para que el sandbox anidado de Kiro Crew funcione dentro de Docker Desktop/WSL2, Kiro A y Kiro B usan `seccomp:unconfined` y `apparmor:unconfined`; esto reduce el aislamiento y requiere mantener los dashboards limitados a localhost. El target `access-test` permite comprobar las capacidades del contenedor.

`kirocrew-seccomp.json` se conserva como perfil experimental documentado, pero no se aplica por defecto: su compatibilidad debe probarse en cada combinación de Docker Desktop, WSL2 y arquitectura antes de reemplazar `unconfined`. Consulta [`docs/security.md`](docs/security.md) para el modelo de amenazas y la configuración de credenciales.

## Setup rápido

Desde WSL2, en el directorio del proyecto:

```bash
cp .env.example .env
# Edita PROJECTS_BASE si quieres usar repositorios fuera de ./projects
docker compose up -d
```

Los servicios `kiro-a-config` y `kiro-b-config` aplican automáticamente los valores seguros de
concurrencia para Knowledge en sus respectivos volúmenes persistentes antes de iniciar Kiro A y Kiro B.
No borra sesiones, memoria, credenciales ni fuentes existentes. Ambas instancias se construyen
localmente desde `Dockerfile.kirocrew` sobre la imagen base configurada, para mantener un timeout
ACP de initialize reproducible.

### Bootstrap automático de Kiro CLI

Cada servicio `kiro-a-config` y `kiro-b-config` ejecuta este bootstrap antes de iniciar su gateway:

1. Instala Kiro CLI desde `https://cli.kiro.dev/install` si no existe en `/home/kirocrew/.local/bin/kiro-cli`.
2. Ejecuta `kirocrew setup --agent-only` para regenerar los agent specs administrados.
3. Reaplica los valores de Knowledge.
4. Ejecuta `kiro-cli whoami` y crea `.kiro_cli_setup_complete` únicamente cuando la cuenta ya está autenticada.

Por tanto, después de la autenticación inicial de cada cuenta, el flujo normal queda reducido a:

```bash
docker compose up -d
```

El login no se automatiza porque requiere la interacción del propietario con IAM Identity Center.
Las credenciales permanecen en los volúmenes separados `kiro-a-home` y `kiro-b-home`.

El valor inicial `PROJECTS_BASE=./projects` permite arrancar el stack sin crear rutas externas. Para usar el filesystem nativo de WSL2, por ejemplo:

```dotenv
PROJECTS_BASE=/home/your-user/repos
```

En Windows con repositorios bajo una unidad montada, usa una ruta Linux visible desde WSL2:

```dotenv
PROJECTS_BASE=/mnt/c/Users/your-windows-user/Documents/Repositories
```

Las rutas bajo `/mnt/c` suelen tener peor rendimiento de I/O que las rutas dentro del filesystem de WSL2.

### Formato de rutas según la terminal

No mezcles formatos de ruta entre terminales:

- Desde WSL2: `PROJECTS_BASE=/mnt/c/Users/your-windows-user/Documents/Repositories`.
- Desde PowerShell o Windows: `PROJECTS_BASE=C:/Users/your-windows-user/Documents/Repositories`.

Si ejecutas `docker compose` desde PowerShell con una ruta `/mnt/c/...`, Docker Desktop puede crear un montaje vacío y KiroCrew no verá los repositorios. Si cambias de terminal, actualiza el `.env` local y recrea el servicio.

## Comandos

| Comando | Descripción |
| --- | --- |
| `make up` | Aplica la configuración segura y luego inicia KiroCrew en segundo plano. |
| `make up-a` | Reconstruye e inicia solo Kiro A desde la configuración central. |
| `make up-b` | Reconstruye e inicia solo Kiro B desde la configuración central. |
| `make configure` | Reaplica los valores de concurrencia de Knowledge sin borrar el volumen. |
| `make down` | Detiene y elimina los contenedores, sin borrar volúmenes. |
| `make restart` | Detiene y vuelve a iniciar el stack. |
| `make logs` | Sigue los logs de KiroCrew. |
| `make logs-a` / `make logs-b` | Sigue los logs de una instancia concreta. |
| `make shell` | Abre un `bash` interactivo dentro de KiroCrew. |
| `make shell-a` / `make shell-b` | Abre un shell en una instancia concreta. |
| `make status` | Muestra el estado de Compose y el health del contenedor. |
| `make update` | Descarga la imagen base, reconstruye el runtime local y recrea KiroCrew. |
| `make docker-test` | Ejecuta `docker ps` dentro de KiroCrew. |
| `make access-test` | Verifica usuario, escritura, Docker y Node dentro de KiroCrew. |
| `make token` | Genera una URL autenticada para el dashboard. |
| `make node-test` | Verifica Node.js y npm dentro de KiroCrew. |
| `make gh-test` | Verifica GitHub CLI y su estado de autenticación. |
| `make gcloud-test` | Verifica Google Cloud CLI, cuentas y configuración activa. |
| `make kubectl-test` | Verifica kubectl y el plugin de autenticación para GKE. |
| `make kiro-login-a` | Inicia el login interactivo de Kiro CLI para Kiro A. |
| `make kiro-login-b` | Inicia el login interactivo de Kiro CLI para Kiro B. |
| `make backup` | Crea un backup timestamped del estado persistente. |
| `make project-up NAME=X` | Levanta el stack Docker de un proyecto montado. |
| `make project-down NAME=X` | Detiene el stack Docker de un proyecto montado. |

### Usar Make sin instalarlo en el host

El servicio `make` se inicia bajo el perfil `tools` y usa una imagen basada en `docker:cli` con Make instalado. Ejecuta los targets con Docker CLI:

```bash
docker compose run --rm make up
docker compose run --rm make configure
docker compose run --rm make down
docker compose run --rm make restart
docker compose run --rm make logs
docker compose run --rm make shell
docker compose run --rm make status
docker compose run --rm make update
docker compose run --rm make docker-test
docker compose run --rm make node-test
docker compose run --rm make gh-test
docker compose run --rm make kiro-login-a
# Repite para la segunda cuenta:
docker compose run --rm make kiro-login-b
docker compose run --rm make access-test
docker compose run --rm make token
docker compose run --rm make backup
docker compose run --rm make project-up NAME=demo-app
docker compose run --rm make project-down NAME=demo-app
```

Para que Compose pueda montar los proyectos cuando se ejecuta desde el contenedor de Make, `PROJECTS_BASE` debe ser una ruta absoluta visible para Docker Desktop/WSL2. El valor local recomendado ya cumple esto, por ejemplo `/mnt/c/Users/your-windows-user/Documents/Repositories`. El valor relativo `./projects` funciona para el stack normal; cámbialo a una ruta absoluta si usarás el servicio `make`.

Equivalentes directos:

```bash
docker compose up -d
docker compose down
docker compose logs -f kiro-a kiro-b
docker compose exec kiro-a bash
docker compose up -d --force-recreate kiro-a kiro-b
```

## Proyectos de trabajo

Por defecto, el directorio configurado en `PROJECTS_BASE` se monta así:

```text
PROJECTS_BASE/<project-name>
  -> /home/kirocrew/projects/<project-name>
```

Por ejemplo, un repositorio ubicado en `./projects/demo-app` aparecerá dentro de KiroCrew como `/home/kirocrew/projects/demo-app`.

El montaje de todo el directorio es práctico para un bootstrap. Si necesitas menor privilegio, reemplázalo en `compose/kiro-a.yml` y `compose/kiro-b.yml` por montajes explícitos:

```yaml
      - ${PROJECTS_BASE}/demo-app:/home/kirocrew/projects/demo-app
      - ${PROJECTS_BASE}/another-app:/home/kirocrew/projects/another-app
```

Para generar un bloque para un proyecto concreto:

```bash
./scripts/add-project.sh demo-app
./scripts/add-project.sh demo-app /absolute/path/to/demo-app
```

El helper valida el nombre y que el directorio exista. Solo imprime el bloque; no modifica automáticamente el Compose para evitar cambios accidentales.

### Stacks de proyectos y red compartida

KiroCrew crea la red Docker `kirocrew-net`. Un stack de proyecto que necesite ser accesible desde KiroCrew debe declarar esa red como externa y conectar explícitamente los servicios necesarios:

```yaml
networks:
  kirocrew-net:
    external: true

services:
  app:
    networks:
      - default
      - kirocrew-net
```

Levanta primero KiroCrew con `docker compose up -d` o `docker compose run --rm make up`. El nombre de la red debe coincidir exactamente; la red no conecta automáticamente todos los stacks.

`make project-up NAME=demo-app` usa `PROJECT_PROFILE=dev` por defecto y busca `demo-app/infra/docker/compose.yml`. Puedes cambiar ambos valores en `.env`.

## Dashboards

- Kiro A: [http://localhost:5476](http://localhost:5476)
- Kiro B: [http://localhost:5477](http://localhost:5477)

Ambos puertos están limitados a `127.0.0.1`.

## Verificar Docker dentro de KiroCrew

```bash
docker exec kiro-a docker ps
docker exec kiro-a docker compose version
```

El primer comando debe mostrar los contenedores visibles para Docker Desktop. El segundo confirma que el plugin Compose fue inyectado por el servicio `docker-cli`.

Para generar un enlace autenticado al dashboard:

```bash
docker compose run --rm make token
```

El token se imprime únicamente en la terminal; no lo guardes en Git ni lo compartas públicamente.

## Kiro CLI y errores de inicialización

El dashboard puede estar saludable aunque las sesiones de chat no puedan inicializarse si Kiro CLI no está autenticado. Completa el login con el flujo de dispositivo desde una terminal interactiva:

```bash
docker compose run --rm make kiro-login-a
# Repite para la segunda cuenta:
docker compose run --rm make kiro-login-b
```

Verifica que cada instancia quedó asociada a la cuenta correcta:

```bash
docker compose exec kiro-a kiro-cli whoami
docker compose exec kiro-b kiro-cli whoami
```

No compartas los volúmenes `kiro-a-home` y `kiro-b-home`: contienen el estado de autenticación
independiente de cada cuenta.

El mensaje `Request initialize timed out` también puede aparecer cuando el agente seleccionado carga MCPs que no responden. El agente completo `kirocrew` puede depender de `kirocrew-core`, `kirocrew-computer`, `kirocrew-cron`, `auto-improvement` y `mochi`; si alguno falla durante el handshake, usa temporalmente el agente `kirocrew-lite`, que no carga MCPs:

```bash
docker exec kiro-a kirocrew config set agent.default_agent kirocrew-lite
docker compose up -d --force-recreate kiro-a kiro-b
```

Para volver al agente completo después de reparar sus MCPs:

```bash
docker exec kiro-a kirocrew config set agent.default_agent default
docker compose up -d --force-recreate kiro-a kiro-b
```

La configuración local recomendada usa `session.eager_spawn=false`, `agent.subagent_auto_max=8`, `taskrunner.max_parallel_steps=8` y `mcp_gateway.max_backends=16`. Para Knowledge, `kiro-a-config` y `kiro-b-config` aplican `knowledge.max_sources=100`, `knowledge.extraction_pool_size=1` y `knowledge.folder_ingest_chunk_budget=25`. Estos valores se guardan en los volúmenes separados `kiro-a-home` y `kiro-b-home`; los comandos siguientes inspeccionan Kiro A:

```bash
docker exec kiro-a kirocrew config get session.eager_spawn
docker exec kiro-a kirocrew config get agent.subagent_auto_max
docker exec kiro-a kirocrew config get taskrunner.max_parallel_steps
docker exec kiro-a kirocrew config get mcp_gateway.max_backends
docker exec kiro-a kirocrew config get knowledge.max_sources
docker exec kiro-a kirocrew config get knowledge.extraction_pool_size
docker exec kiro-a kirocrew config get knowledge.folder_ingest_chunk_budget
```

Los valores se pueden cambiar en `.env` y reaplicar con `make configure`. Bajar
`knowledge.extraction_pool_size` o `knowledge.folder_ingest_chunk_budget` reduce
la velocidad máxima de indexación, pero evita que una fuente grande bloquee el
chat ACP. No es necesario aumentar la memoria de Docker mientras el host conserve
memoria disponible; primero se debe limitar la concurrencia y procesar las fuentes
por lotes.

El error `Request initialize timed out after 30s` ocurre durante el handshake ACP,
antes de procesar el mensaje. El runtime local construido por
`Dockerfile.kirocrew` eleva ese presupuesto a `KIROCREW_ACP_INIT_TIMEOUT_SECS`
(120 segundos por defecto) y lo aplica en el call site de `initialize`
(ver ADR-006 y ADR-008). No confundirlo con `chat_turn_timeout_secs`, que
controla la duración del turno después de inicializar la sesión.

```bash
docker exec kiro-a kirocrew config get agent.session_start_timeout_secs
docker inspect kiro-a kiro-b --format '{{.Name}} {{range .Config.Env}}{{println .}}{{end}}' | grep KIROCREW_ACP_INIT_TIMEOUT_SECS
```

Si el mensaje muestra el valor configurado (p.ej. `timed out after 240s`), el
handshake está tardando de verdad. En las mediciones de referencia con el host
despejado, `initialize` responde en ~2s y los MCP de Kiro Crew en ~1s, así que
un timeout al presupuesto completo casi siempre indica contención del host, no
la ruta del proyecto ni Knowledge. Diagnóstico recomendado:

```bash
docker stats --no-stream
docker logs kiro-a --since 30m 2>&1 | Select-String "MCP probe failed|timed out"
```

Si otros contenedores consumen CPU de forma sostenida, limítalos en lugar de
detenerlos (`docker update --cpus 1.0 <contenedor>`). Como optimización
adicional, `PROJECTS_BASE` rinde mejor en una ruta nativa de WSL2 que en un
bind-mount de Windows (`C:\...`); no es requisito, pero reduce la latencia de
I/O con muchos archivos pequeños.

## Enmascarado del árbol de proyectos

Recorrer directorios sobre el bind-mount de Windows cuesta ~1 ms por entrada. Un
repositorio con un `node_modules` grande convierte cualquier recorrido del árbol
en una operación de minutos que deja al gateway sin event loop, y el síntoma es
`Request initialize timed out`. En `premium-prb/engineering-governance` el
recorrido completo eran 58 213 archivos en 64.1 s, de los cuales `node_modules`
aportaba 53 039 archivos y 57.1 s.

`make masks` escanea `PROJECTS_BASE` y genera `docker-compose.override.yml`
montando un `tmpfs` vacío sobre cada directorio de dependencias o caché, así el
contenedor no los ve y ningún recorrido desciende en ellos. Con las máscaras
activas ese mismo recorrido baja a 2 471 archivos en 6.3 s. Ver ADR-009.

```bash
make masks                                              # regenerar el override
make mask-report PROJECT=premium-prb/engineering-governance   # medir el árbol
```

`up`, `restart` y `update` encadenan `masks`, de modo que el override nunca queda
obsoleto. Después de clonar un repositorio o instalar dependencias en el host,
ejecuta `make masks` para crear la máscara correspondiente.

La lista se controla con `KIROCREW_MASK_DIRS` en `.env`. `.git`, `build` y `dist`
se dejan visibles a propósito porque su costo es marginal y el agente los
necesita. Los directorios enmascarados aparecen **vacíos** dentro del
contenedor: si un flujo necesita las dependencias reales, quita ese nombre de la
lista y vuelve a generar. Un `npm install` dentro del contenedor escribe en el
`tmpfs` (`KIROCREW_MASK_TMPFS_SIZE`, 1 GB por defecto) y no se comparte con
Windows ni sobrevive al reinicio.

`docker-compose.override.yml` es un archivo generado y específico del host; está
en `.gitignore` y no debe editarse a mano.

## Identidad de GitHub por instancia

Cada instancia autentica con su propia cuenta de GitHub (ADR-010). Configura
los PATS en `.env`:

```dotenv
GH_USER_A=Jerson-Martinez-JEM0925
GH_TOKEN_A=ghp_...
GH_USER_B=jersonmartinez
GH_TOKEN_B=ghp_...

# Opcional:
#GH_EMAIL_A=...   # por defecto: <GH_USER_A>@users.noreply.github.com
#GH_EMAIL_B=...
```

Al arrancar, `kiro-a-config` y `kiro-b-config` escriben `~/.gitconfig` en el
volumen persistente con `user.name`, `user.email` y el helper de credenciales
para `gh`. `gh` no requiere `gh auth login`: lee `GH_TOKEN` en cada invocación,
por lo que nada se pierde al reiniciar.

```bash
make gh-identity    # verifica ambas cuentas
make gh-test        # detalla versión, auth, login, git name/email
```

Importante:

- Los PATS **nunca** deben ir a Git; `.env` y `docker-compose.override.yml`
  están en `.gitignore`.
- Cada instancia empuja como su cuenta. Asegúrate de que el repositorio remoto
  use HTTPS (`https://github.com/...`) para aprovechar el helper de `gh`.
- Si un token expira, cámbialo en `.env` y reinicia el contenedor correspondiente.

## Node.js dentro de KiroCrew

Node.js 20, npm, npx y corepack se inyectan mediante el servicio init `node-cli`, sin instalar Node.js en el host:

```bash
docker compose run --rm make node-test
docker exec kiro-a bash -l -c 'node --version && npm --version && npx --version'
```

El volumen `node-bin` es una caché de herramientas; puedes recrearlo con `docker compose up -d --force-recreate` si cambias la versión o el contenido del sidecar. El servicio Dockerizado de Make prioriza las variables que recibe del Compose sobre los valores de `.env`, para conservar correctamente las rutas host al ejecutar Compose anidado.

## Persistencia y backup

Los volúmenes `kiro-a-home` y `kiro-b-home` contienen, respectivamente, la memoria,
configuración, credenciales e historial de Kiro A y Kiro B. Ambos persisten entre recreaciones.

No ejecutes `docker volume rm kiro-a-home kiro-b-home` ni `docker compose down -v` sin un backup.
Para crear backups de ambas instancias:

```bash
make backup
```

También puedes ejecutar el equivalente desde el servicio Dockerizado de Make:

```bash
docker compose run --rm make backup
```

## Troubleshooting

### Docker socket o permisos

Confirma que Docker Desktop está activo y que la integración WSL2 está habilitada:

```bash
docker version
docker compose version
ls -l /var/run/docker.sock
```

Si el socket existe pero `docker ps` falla dentro del contenedor, comprueba su GID y configúralo en `.env`:

```bash
stat -c '%g' /var/run/docker.sock
# Actualiza DOCKER_SOCKET_GID en .env con ese valor
docker compose logs docker-cli
docker compose up -d --force-recreate
```

En Docker Desktop + WSL2 normalmente el socket aparece como `root:root`, por lo que `DOCKER_SOCKET_GID=0` es el valor esperado. KiroCrew sigue ejecutándose como el usuario interno `kirocrew`; `group_add` solo añade el grupo suplementario necesario para acceder al socket.

### Rutas de proyectos

Comprueba que el directorio configurado exista desde WSL2:

```bash
set -a
source .env
set +a
ls -la "$PROJECTS_BASE"
```

Si editaste `.env`, recrea el servicio para aplicar el montaje:

```bash
docker compose up -d --force-recreate kiro-a kiro-b
```

### Volumen corrupto o estado inconsistente

Realiza primero el backup descrito arriba. Elimina o restaura el volumen únicamente después de confirmar que la copia es válida. El estado persistente no se borra durante un `docker compose down` normal.

### Chromium / Playwright

La imagen instala `ffmpeg`, `libreoffice` (incluidos Impress y Draw), las bibliotecas de ejecución de Chromium y `@playwright/cli` 0.1.18 para ambos agentes. El sidecar `node-cli` descarga Chromium en el volumen persistente `playwright-browsers` y cada instancia registra las skills en `/home/kirocrew/.agents/skills/playwright-cli`.

El wrapper selecciona Chromium automáticamente cuando se ejecuta `playwright-cli open`; también puedes indicarlo explícitamente:

```bash
docker compose exec kiro-a playwright-cli open http://host.docker.internal:3000
docker compose exec kiro-b playwright-cli open http://host.docker.internal:3000 --browser=chromium
```

`SYS_ADMIN` está incluido porque el sandbox de Chromium lo requiere. Si el browser mode falla, revisa que ninguna configuración externa haya eliminado la capability y consulta los logs de KiroCrew.

Para PPTX Maker, LibreOffice se ejecuta en modo headless dentro de ambos contenedores para generar miniaturas y previsualizaciones PDF:

```bash
docker compose exec kiro-a libreoffice --headless --version
docker compose exec kiro-b libreoffice --headless --version
```

## Estructura

```text
.
├── docker-compose.yml
├── compose/
│   ├── shared.yml
│   ├── kiro-a.yml
│   └── kiro-b.yml
├── Dockerfile.make
├── .dockerignore
├── .env.example
├── Makefile
├── projects/.gitkeep
├── scripts/
│   ├── add-project.sh
│   └── generate-mask-override.sh
├── tests/validate.sh
├── .github/workflows/validate.yml
└── docs/
    ├── security.md
    └── decisions/
        ├── ADR-001-docker-cli-sidecar.md
        ├── ADR-002-node-cli-sidecar.md
        ├── ADR-003-shared-network.md
        └── ADR-010-per-instance-github-identity.md
```

## Licencia

Este proyecto se distribuye bajo la licencia MIT. Consulta [`LICENSE`](LICENSE).

## Contribuir

Las configuraciones públicas deben usar placeholders y permanecer libres de rutas personales, nombres de proyectos privados y credenciales. Usa `.env` para tus valores locales; está excluido de Git. Antes de abrir un PR, ejecuta:

```bash
./tests/validate.sh
docker compose --profile tools build make
git diff --check
```

La validación no inicia KiroCrew ni requiere credenciales. La prueba completa de runtime
requiere Docker Desktop/WSL2 y se debe ejecutar siguiendo el setup rápido.
