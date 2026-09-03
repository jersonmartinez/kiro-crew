# ADR-012: Permitir autenticación de GCloud desde sesiones ACP

## Status
Accepted

## Context

KiroCrew autentica Google Cloud de forma independiente dentro del home persistente de cada agente. El proceso gateway podía usar la cuenta `gcloud` configurada, pero las sesiones ACP no: el launcher del sandbox montaba un directorio vacío sobre `/home/kirocrew/.config/gcloud` antes de iniciar el subproceso del agente.

Esto hacía que `gcloud auth list` apareciera vacío en los prompts aunque la instancia estuviera autenticada. También impedía al agente inspeccionar recursos GCP autorizados necesarios para el flujo de desarrollo.

## Decision

Mantener `/home/kirocrew/.config/gcloud` disponible dentro de las sesiones ACP para ambas instancias de KiroCrew. El build de la imagen modifica el código fuente del launcher del sandbox en `Dockerfile.kirocrew`, eliminando ese directorio de las listas de directorios y archivos protegidos del launcher.

La autenticación sigue siendo local a cada instancia y persistente en `kiro-a-home` o `kiro-b-home`. El proyecto no incorpora credenciales en la imagen ni en el repositorio. El proyecto GCP activo se configura por separado en cada instancia.

## Alternatives Considered

### Mantener GCloud oculto y ejecutar comandos fuera de ACP

Conserva el aislamiento de credenciales más fuerte, pero evita que los prompts inspeccionen directamente recursos GCP y obliga al operador a retransmitir cada resultado.

### Exponer una credencial de service account de corta duración y mínimo privilegio

Reduciría el alcance de la credencial disponible para el agente, pero requiere un flujo adicional de emisión y rotación que no forma parte de este bootstrap de desarrollo local.

### Exponer la configuración completa de gcloud

Es el enfoque seleccionado para el flujo actual de desarrollo local porque el login OAuth ya vive en el volumen de la instancia y el agente necesita el comportamiento nativo de `gcloud`. No es apropiado para un entorno público en Internet o de producción compartida.

## Consequences

- Los prompts ACP pueden usar la cuenta `gcloud` autenticada y el proyecto configurado.
- `kiro-a` y `kiro-b` siguen aisladas mediante volúmenes home con nombres separados.
- El sandbox continúa ocultando `.ssh`, `.gnupg`, `.docker`, `.azure` y otras rutas protegidas.
- Cualquiera que pueda ejecutar prompts en una instancia puede usar las credenciales GCP de esa instancia; los permisos IAM deben ser mínimos y apropiados para el entorno.
- Las bases de datos de credenciales permanecen fuera de Git, Dockerfiles, diagramas generados y `.env.example`.
