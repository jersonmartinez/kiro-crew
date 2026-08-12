# KiroCrew Docker Compose Bootstrap

Bootstrap público para ejecutar [KiroCrew](https://github.com/kirodotdev/kirocrew) con Docker Desktop y WSL2. Incluye persistencia para el estado del agente, Docker CLI + Compose dentro del contenedor, acceso configurable a proyectos de trabajo y un dashboard publicado únicamente en localhost.

La configuración no contiene rutas ni nombres de proyectos específicos de ningún entorno. El valor por defecto usa `./projects`; puedes cambiarlo en tu `.env` para reutilizar tus repositorios existentes.

## Qué incluye

- Imagen oficial `ghcr.io/kirodotdev/kirocrew:stable`.
- Servicio init `docker-cli` basado en `docker:cli`.
- Docker CLI y el plugin Compose inyectados mediante el volumen `docker-bin`.
- Estado persistente en el volumen nombrado `kirocrew-home`.
- Proyectos disponibles en `/home/kirocrew/projects/<nombre>`.
- Dashboard en `http://localhost:5476`, sin exposición en interfaces externas.
- Capacidad `SYS_ADMIN` para el sandbox de Chromium/Playwright.
- Makefile y helper para las operaciones habituales.

## Prerrequisitos

- Docker Desktop instalado y ejecutándose.
- Integración WSL2 habilitada para tu distribución Linux.
- WSL2 con `docker` y `docker compose` disponibles.
- Bash y `make` disponibles en WSL2.
- Un directorio para los proyectos que KiroCrew podrá leer y modificar.

El socket Docker otorga acceso equivalente a root sobre el Docker Engine del host. Por eso esta configuración está orientada a desarrollo local y no debe exponerse directamente a Internet.

## Setup rápido

Desde WSL2, en el directorio del proyecto:

```bash
cp .env.example .env
# Edita PROJECTS_BASE si quieres usar repositorios fuera de ./projects
make up
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

## Dashboard

Abre [http://localhost:5476](http://localhost:5476). El puerto está limitado a `127.0.0.1`.

## Verificar Docker dentro de KiroCrew

```bash
docker exec kirocrew docker ps
docker exec kirocrew docker compose version
```

El primer comando debe mostrar los contenedores visibles para Docker Desktop. El segundo confirma que el plugin Compose fue inyectado por el servicio `docker-cli`.

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
├── .env.example
├── Makefile
├── projects/.gitkeep
├── scripts/add-project.sh
├── tasks/plan.md
└── docs/decisions/ADR-001-docker-cli-sidecar.md
```

## Contribuir

Las configuraciones públicas deben usar placeholders y permanecer libres de rutas personales, nombres de proyectos privados y credenciales. Usa `.env` para tus valores locales; está excluido de Git. Antes de abrir un PR, ejecuta:

```bash
docker compose config --quiet
git diff --check
```
