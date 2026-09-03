# ADR-013: Incluir el cliente OpenSSH para IAP de GCP

## Estado
Aceptado

## Contexto

Los contenedores de KiroCrew incluyen Google Cloud CLI y pueden autenticarse en GCP, pero `gcloud compute ssh` también necesita un cliente SSH local. Sin OpenSSH, el comando informa que la plataforma no admite SSH aunque la cuenta GCP y los permisos de IAP sean válidos.

El flujo requerido es conectarse desde shells ACP a VMs de desarrollo mediante Identity-Aware Proxy (IAP), con la posibilidad de ejecutar un comando remoto. KiroCrew no necesita aceptar conexiones SSH entrantes.

## Decisión

Instalar el paquete Debian `openssh-client` en la imagen de runtime compartida que construye `Dockerfile.kirocrew`. Verificar `/usr/bin/ssh`, `ssh -V` y `gcloud compute ssh --help` en ambas instancias y en CI.

No instalar un servidor SSH, publicar un puerto SSH, añadir claves privadas a la imagen ni cambiar el entrypoint del contenedor. La autenticación remota seguirá controlada por la identidad GCP autenticada, los permisos IAM de Compute Engine/IAP y la configuración SSH de la VM.

## Alternativas consideradas

### Instalar un servidor SSH

Rechazado: KiroCrew solo inicia conexiones SSH salientes. Un servidor SSH añadiría una superficie de ataque entrante innecesaria y exigiría gestionar puertos, cuentas y ciclo de vida.

### Usar un cliente SSH del host

Rechazado: los comandos ACP se ejecutan dentro del contenedor y necesitan un runtime consistente. Depender del cliente del host haría que el flujo dependiera del entorno.

### Guardar una clave privada en la imagen o el repositorio

Rechazado: las claves privadas deben permanecer fuera de Git y de las imágenes de contenedor. `gcloud compute ssh` puede gestionar la conexión mediante el flujo autenticado de GCP.

## Consecuencias

- `gcloud compute ssh` funciona desde Kiro A y Kiro B cuando los permisos de GCP/IAP están configurados.
- No se introduce ningún puerto nuevo ni servicio entrante.
- La imagen de runtime incorpora el cliente OpenSSH y sus dependencias.
- El acceso a VMs remotas continúa siendo acceso privilegiado a infraestructura y debe usar IAM con mínimo privilegio.
- Las contraseñas, claves privadas, tokens de acceso y salidas de comandos que contengan secretos no deben almacenarse en Git ni en la documentación.
