# ADR-009: Enmascarar directorios de dependencias sobre montajes lentos

## Status

Accepted (2026-08-18). Cierra la causa raíz que ADR-006 y ADR-008 solo
mitigaban con timeouts.

## Context

Tras hacer efectivo el presupuesto del handshake ACP (ADR-008), el error
persistía como `Request initialize timed out after 240s`, pero **solo con
determinados proyectos**: un repositorio pequeño respondía en segundos mientras
`premium-prb/engineering-governance` agotaba el presupuesto completo de forma
reproducible.

Mediciones dentro del contenedor, con `PROJECTS_BASE` montado desde
`C:/Users/.../Repositories` (Docker Desktop, virtiofs):

| Recorrido del árbol de `engineering-governance` | Archivos | Tiempo |
| --- | --- | --- |
| Completo | 58 213 | 64.1 s |
| Sin `node_modules` / `.git` / `build` | 196 | 0.5 s |

Desglose por directorio:

| Directorio | Archivos | Tiempo |
| --- | --- | --- |
| `node_modules` | 53 039 | 57.1 s |
| `.git` | 1 563 | 3.1 s |
| `build` | 712 | 3.6 s |
| `assess` | 2 199 | 0.9 s |

`node_modules` concentraba el **89 %** del costo. El montaje de Windows paga
aproximadamente 1 ms por entrada de directorio, de modo que una sola pasada
sobre el árbol cuesta ~1 minuto y varias pasadas concurrentes superan cualquier
presupuesto razonable.

Dos comprobaciones delimitan el mecanismo:

- Un `initialize` lanzado directamente contra `kiro-cli acp --agent kirocrew`
  con `cwd` en ese repositorio responde en ~1.9 s (8/8 intentos). El handshake
  en sí no recorre el árbol.
- El gateway es un único proceso asyncio. Cuando el recorrido del árbol se
  ejecuta de forma bloqueante, el reader loop de ACP queda inanido y la
  respuesta de `initialize` —ya emitida por kiro-cli— no se lee dentro del
  presupuesto. El mismo patrón explica los `MCP probe failed: timeout after 15s`
  agrupados en las mismas ventanas.

No se identificó con certeza el componente que dispara el recorrido (selección
de proyecto, snapshot de contexto o indexado). La decisión no depende de ello:
eliminar el costo de I/O resuelve el problema con independencia del llamante.

Descartado explícitamente: la longitud de la ruta y el número de repositorios
bajo `PROJECTS_BASE`. Montar un directorio solo lo expone; el costo aparece al
recorrerlo, y se concentra en los directorios de dependencias.

## Decision

Enmascarar cada directorio de dependencias/caché del árbol de proyectos con un
`tmpfs` vacío, de forma que el contenedor no lo vea y ningún recorrido descienda
en él.

- `scripts/generate-mask-override.sh` recorre `PROJECTS_BASE` con
  `find -maxdepth 4 ... -prune` y genera `docker-compose.override.yml` con un
  `tmpfs` por coincidencia. El `-prune` detiene el descenso en cada acierto, así
  que el propio generador es económico sobre el montaje lento.
- Las máscaras son rutas **del contenedor**, sin rutas del host, por lo que el
  archivo generado es portable aunque el escaneo sea específico de la máquina.
- `make masks` regenera el archivo, y `up`, `restart` y `update` lo declaran
  como prerrequisito para que nunca quede obsoleto.
- Lista por defecto (`KIROCREW_MASK_DIRS`): `node_modules`, `.venv`, `venv`,
  `vendor`, `target`, `__pycache__`, `.next`, `.nuxt`, `.docusaurus`, `.cache`,
  `.pytest_cache`, `.mypy_cache`, `.gradle`.

`.git`, `build` y `dist` se dejan visibles a propósito: su costo medido es
marginal y el agente los necesita para operar (`git`) o inspeccionar
artefactos.

## Alternatives Considered

### Seguir subiendo `KIROCREW_ACP_INIT_TIMEOUT_SECS`

Rechazado como solución. Un recorrido de 64 s por pasada escala con el tamaño
del repositorio: cualquier presupuesto acaba siendo insuficiente y, mientras
espera, el agente queda inutilizable. El timeout se conserva como red de
seguridad, no como remedio.

### Montar solo repositorios seleccionados en vez de todo `PROJECTS_BASE`

Rechazado como remedio del timeout: reduce la superficie expuesta, que es buena
higiene, pero un repositorio seleccionado sigue arrastrando su `node_modules` y
el recorrido sigue costando lo mismo. Es ortogonal al problema.

### Migrar `PROJECTS_BASE` a almacenamiento nativo de WSL2

Correcto en el fondo y descartado por coste: son 18.17 GB y más de 100
repositorios que el usuario edita desde Windows. Queda documentado en el README
como optimización opcional para casos puntuales.

### Volúmenes anónimos en lugar de `tmpfs`

Rechazado: acumulan volúmenes huérfanos en cada recreación. `tmpfs` no deja
residuos, no consume disco y se reconstruye vacío en cada arranque.

### Confiar en `.gitignore` o un archivo de ignore del agente

Rechazado: `node_modules` ya está en `.gitignore` del repositorio afectado y el
recorrido lo atravesaba igualmente. La exclusión debe imponerse en la capa de
montaje para ser efectiva.

## Consequences

- El recorrido de `engineering-governance` baja de **64.1 s / 58 213 archivos**
  a **6.3 s / 2 471 archivos** (10x). El código fuente, `docs/` y `git`
  permanecen accesibles y verificados.
- Los directorios enmascarados se ven **vacíos** dentro del contenedor. Un
  `npm install` ejecutado por el agente escribe en el `tmpfs` (limitado por
  `KIROCREW_MASK_TMPFS_SIZE`, 1 GB por defecto) y no se comparte con Windows ni
  sobrevive al reinicio. Si un flujo necesita las dependencias reales, hay que
  quitar ese directorio de `KIROCREW_MASK_DIRS` y regenerar.
- `docker-compose.override.yml` es generado y específico del host: está en
  `.gitignore` y no debe editarse a mano.
- Al clonar un repositorio nuevo o instalar dependencias en el host hay que
  ejecutar `make masks` (o `make up`, que lo encadena) para que la máscara
  correspondiente exista.
- El diagnóstico queda reproducible con `make mask-report PROJECT=<ruta>`.
