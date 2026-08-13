# KiroCrew Docker Compose Bootstrap

Bootstrap público para ejecutar [KiroCrew](https://github.com/kirodotdev/kirocrew) con Docker Desktop y WSL2. Incluye persistencia para el estado del agente, Docker CLI + Compose dentro del contenedor, acceso configurable a proyectos de trabajo y un dashboard publicado únicamente en localhost.

La configuración no contiene rutas ni nombres de proyectos específicos de ningún entorno. El valor por defecto usa `./projects`; puedes cambiarlo en tu `.env` para reutilizar tus repositorios existentes.

## Qué incluye

- Imagen oficial `ghcr.io/kirodotdev/kirocrew:stable`.
- Servicio init `docker-cli` basado en `docker:cli`.
- Servicio init `node-cli` basado en `node:20-slim` (Node.js, npm, npx).
- Servicio init `gh-cli` basado en `debian:trixie-slim` (GitHub CLI).
- Docker CLI y el plugin Compose inyectados mediante el volumen `docker-bin`.
- Node.js CLI inyectado mediante el volumen `node-bin`.
- GitHub CLI inyectado mediante el volumen `gh-bin`.
- Docker CLI disponible también en shells interactivos/login mediante `/etc/profile.d`.
- Estado persistente en el volumen nombrado `kirocrew-home`.
- Proyectos disponibles en `/home/kirocrew/projects/<nombre>`.
- Dashboard en `http://localhost:5476`, sin exposición en interfaces externas.
- Capacidad `SYS_ADMIN` para el sandbox de Chromium/Playwright.
- Red compartida `kirocrew-net` para comunicación con stacks de proyectos.
- Makefile y helper para las operaciones habituales.
- Servicio opcional `make` para ejecutar Make dentro de Docker sin instalarlo en el host.

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

No se usa `privileged: true`, `sudo`, `NET_ADMIN` ni un perfil seccomp deshabilitado. El target `access-test` permite comprobar estas capacidades sin elevar permisos adicionales.

## Setup rápido

Desde WSL2, en el directorio del proyecto:

```bash
cp .env.example .env
# Edita PROJECTS_BASE si quieres usar repositorios fuera de ./projects
docker compose up -d
```

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
| `make up` | Inicia el sidecar del CLI y KiroCrew en segundo plano. |
| `make down` | Detiene y elimina los contenedores, sin borrar volúmenes. |
| `make restart` | Detiene y vuelve a iniciar el stack. |
| `make logs` | Sigue los logs de KiroCrew. |
| `make shell` | Abre un `bash` interactivo dentro de KiroCrew. |
| `make status` | Muestra el estado de Compose y el health del contenedor. |
| `make update` | Descarga la imagen configurada y recrea KiroCrew. |
| `make docker-test` | Ejecuta `docker ps` dentro de KiroCrew. |
| `make access-test` | Verifica usuario, escritura, Docker y Node dentro de KiroCrew. |
| `make token` | Genera una URL autenticada para el dashboard. |
| `make node-test` | Verifica Node.js y npm dentro de KiroCrew. |
| `make gh-test` | Verifica GitHub CLI y su estado de autenticación. |
| `make backup` | Crea un backup timestamped del volumen `kirocrew-home`. |
| `make project-up NAME=X` | Levanta el stack Docker de un proyecto montado. |
| `make project-down NAME=X` | Detiene el stack Docker de un proyecto montado. |

### Usar Make sin instalarlo en el host

El servicio `make` se inicia bajo el perfil `tools` y usa una imagen basada en `docker:cli` con Make instalado. Ejecuta los targets con Docker CLI:

```bash
docker compose run --rm make up
docker compose run --rm make down
docker compose run --rm make restart
docker compose run --rm make logs
docker compose run --rm make shell
docker compose run --rm make status
docker compose run --rm make update
docker compose run --rm make docker-test
docker compose run --rm make node-test
docker compose run --rm make gh-test
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
docker compose logs -f kirocrew
docker compose exec kirocrew bash
docker compose up -d --force-recreate kirocrew
```

## Proyectos de trabajo

Por defecto, el directorio configurado en `PROJECTS_BASE` se monta así:

```text
PROJECTS_BASE/<project-name>
  -> /home/kirocrew/projects/<project-name>
```

Por ejemplo, un repositorio ubicado en `./projects/demo-app` aparecerá dentro de KiroCrew como `/home/kirocrew/projects/demo-app`.

El montaje de todo el directorio es práctico para un bootstrap. Si necesitas menor privilegio, reemplázalo en `docker-compose.yml` por montajes explícitos:

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

## Dashboard

Abre [http://localhost:5476](http://localhost:5476). El puerto está limitado a `127.0.0.1`.

## Verificar Docker dentro de KiroCrew

```bash
docker exec kirocrew docker ps
docker exec kirocrew docker compose version
```

El primer comando debe mostrar los contenedores visibles para Docker Desktop. El segundo confirma que el plugin Compose fue inyectado por el servicio `docker-cli`.

Para generar un enlace autenticado al dashboard:

```bash
docker compose run --rm make token
```

El token se imprime únicamente en la terminal; no lo guardes en Git ni lo compartas públicamente.

## GitHub CLI dentro de KiroCrew

GitHub CLI se instala mediante el sidecar `gh-cli`; no se instala en Windows ni dentro de la imagen base. Configura un token local en `.env`:

```dotenv
GH_TOKEN=ghp_your-token-here
```

Nunca publiques ese valor ni lo incluyas en `.env.example`. Después de recrear el stack:

```bash
docker compose up -d --force-recreate
docker exec kirocrew gh --version
docker exec kirocrew gh auth status
docker exec kirocrew gh repo list --limit 3
```

Si un token fue expuesto, revócalo en GitHub y genera uno nuevo antes de continuar.

## Node.js dentro de KiroCrew

Node.js 20, npm, npx y corepack se inyectan mediante el servicio init `node-cli`, sin instalar Node.js en el host:

```bash
docker compose run --rm make node-test
docker exec kirocrew bash -l -c 'node --version && npm --version && npx --version'
```

El volumen `node-bin` es una caché de herramientas; puedes recrearlo con `docker compose up -d --force-recreate` si cambias la versión o el contenido del sidecar. El servicio Dockerizado de Make prioriza las variables que recibe del Compose sobre los valores de `.env`, para conservar correctamente las rutas host al ejecutar Compose anidado.

## Persistencia y backup

El volumen `kirocrew-home` contiene la memoria, configuración, skills e historial de KiroCrew y persiste entre recreaciones del contenedor.

No ejecutes `docker volume rm kirocrew-home` ni `docker compose down -v` sin un backup. Para crear uno:

```bash
docker compose down
docker run --rm \
  -v kirocrew-home:/source \
  -v "$PWD":/backup alpine \
  tar czf /backup/kirocrew-home-backup.tgz -C /source .
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
docker compose up -d --force-recreate kirocrew
```

### Volumen corrupto o estado inconsistente

Realiza primero el backup descrito arriba. Elimina o restaura el volumen únicamente después de confirmar que la copia es válida. El estado persistente no se borra durante un `docker compose down` normal.

### Chromium / Playwright

`SYS_ADMIN` está incluido porque el sandbox de Chromium lo requiere. Si el browser mode falla, revisa que ninguna configuración externa haya eliminado la capability y consulta los logs de KiroCrew.

## Estructura

```text
.
├── docker-compose.yml
├── Dockerfile.make
├── .dockerignore
├── .env.example
├── Makefile
├── projects/.gitkeep
├── scripts/add-project.sh
├── tasks/plan.md
└── docs/
    └── decisions/
        ├── ADR-001-docker-cli-sidecar.md
        ├── ADR-002-node-cli-sidecar.md
        ├── ADR-003-shared-network.md
        └── ADR-004-gh-cli-sidecar.md
```

## Contribuir

Las configuraciones públicas deben usar placeholders y permanecer libres de rutas personales, nombres de proyectos privados y credenciales. Usa `.env` para tus valores locales; está excluido de Git. Antes de abrir un PR, ejecuta:

```bash
docker compose config --quiet
docker compose --profile tools build make
git diff --check
```
