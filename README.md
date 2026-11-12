# Helm Demo: ASP.NET Core en Kubernetes

Ejemplo mínimo para entender el ciclo de entrega con Docker, Helm y Kubernetes local. La página muestra el nombre y mensaje de la aplicación, la versión, el entorno y el pod que la ejecuta. `/health` responde `Healthy` y se usa en las sondas de Kubernetes.

## Requisitos

- Windows 10/11, Visual Studio Code y PowerShell.
- Git.
- .NET 10 SDK.
- Docker Desktop con el motor Linux activo.
- Minikube, Helm 3 o 4 y kubectl. Minikube puede ejecutar kubectl con `minikube kubectl --`.
- WSL 2 y la característica de Windows Virtual Machine Platform para que Docker Desktop ejecute contenedores Linux.

Comprueba las herramientas en PowerShell:

```powershell
dotnet --version
git --version
docker --version
helm version
minikube version
kubectl version --client
```

En Windows se pueden instalar con WinGet (si no están ya instaladas):

```powershell
winget install -e --id Microsoft.DotNet.SDK.10
winget install -e --id Docker.DockerDesktop
winget install -e --id Kubernetes.minikube
winget install -e --id Helm.Helm
winget install -e --id Kubernetes.kubectl
winget install -e --id Git.Git
winget install -e --id Microsoft.VisualStudioCode
```

Si Minikube no queda disponible despues de instalarlo con WinGet, descarga el ejecutable oficial a una carpeta del usuario y agregala al `PATH`:

```powershell
New-Item -ItemType Directory -Force "$HOME\.local\bin" | Out-Null
curl.exe --fail --location --show-error `
  https://storage.googleapis.com/minikube/releases/latest/minikube-windows-amd64.exe `
  --output "$HOME\.local\bin\minikube.exe"
$env:PATH = "$HOME\.local\bin;$env:PATH"
minikube version
```

### Preparar WSL 2 y Docker Desktop en Windows

Abre PowerShell **como administrador** y habilita las características necesarias:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
Restart-Computer
```

Después del reinicio, abre PowerShell normal y ejecuta:

```powershell
wsl --update
wsl --set-default-version 2
wsl --status
```

Abre Docker Desktop, selecciona el motor Linux basado en WSL 2 y espera a que indique que está en ejecución. Verifica con `docker info`. Reinicia la terminal después de instalar herramientas; confirma que `helm`, `kubectl` y `minikube` estén en `PATH`.

## Arquitectura

```text
Navegador -- port-forward (o Ingress opcional) --> Service :80
                                                   |
                                       Deployment --> Pods :8080
                                                   |
                            ConfigMap + Downward API (nombre del pod)
```

Helm renderiza el Deployment, Service, ConfigMap y, opcionalmente, Ingress a partir de `helm/helm-demo/values.yaml`. El Service selecciona los pods mediante los mismos labels que usa el selector del Deployment. La aplicación escucha en el puerto 8080 del contenedor; el Service publica el puerto 80. La sonda de vida y la de disponibilidad consultan `/health`.

## Estructura

```text
.
├── src/HelmDemoApp/          # Aplicación ASP.NET Core
├── helm/helm-demo/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/            # Deployment, Service, ConfigMap, Ingress y helpers
├── Dockerfile                # Compilación multietapa
├── .dockerignore
└── README.md
```

## Ejecutar sin contenedores

Desde la raíz del proyecto:

```powershell
$env:APP_NAME = "helm-demo"
$env:APP_VERSION = "1.0.0"
$env:APP_ENVIRONMENT = "Local"
$env:APP_MESSAGE = "Aplicación desplegada correctamente con Helm"
dotnet run --project .\src\HelmDemoApp\HelmDemoApp.csproj -- --urls http://localhost:8080
```

Abre `http://localhost:8080` y `http://localhost:8080/health`. Para detener la aplicación, pulsa Ctrl+C. Verifica la compilación por separado con:

```powershell
dotnet build .\src\HelmDemoApp\HelmDemoApp.csproj --configuration Release
```

## Construir y probar la imagen Docker

Desde la raíz, con Docker Desktop en ejecución:

```powershell
docker build -t helm-demo:1.0.0 .
docker run --rm -d --name helm-demo-local -p 8080:8080 `
  -e APP_NAME=helm-demo `
  -e APP_VERSION=1.0.0 `
  -e APP_ENVIRONMENT=Local `
  -e "APP_MESSAGE=Aplicación desplegada correctamente con Helm" `
  helm-demo:1.0.0
curl.exe http://localhost:8080/
curl.exe http://localhost:8080/health
docker stop helm-demo-local
```

La respuesta de salud debe ser `Healthy`; la página debe mostrar los valores indicados y `ejecución-local` como pod, ya que el contenedor local no recibe la Downward API.

## Iniciar Minikube

```powershell
minikube start --driver=docker
minikube status
kubectl cluster-info
```

Si prefieres usar el kubectl integrado de Minikube, sustituye `kubectl` por `minikube kubectl --` en los comandos siguientes. Para usar Ingress, activa también el controlador de Minikube:

```powershell
minikube addons enable ingress
```

## Cargar la imagen local

Construye la imagen en Docker y cárgala en Minikube. Esto evita publicar la imagen en un registro:

```powershell
docker build -t helm-demo:1.0.0 .
minikube image load helm-demo:1.0.0
minikube image ls | Select-String helm-demo
```

El chart usa `imagePullPolicy: IfNotPresent`, por lo que Kubernetes puede ejecutar la imagen cargada localmente.

## Instalar con Helm (versión 1.0.0)

Desde la raíz del proyecto, valida y renderiza el chart antes de instalarlo:

```powershell
helm lint .\helm\helm-demo
helm template helm-demo .\helm\helm-demo
```

La salida debe incluir un Deployment con dos réplicas, un Service en el puerto 80, un ConfigMap y no debe incluir Ingress (está deshabilitado por defecto). Instala la release:

```powershell
helm upgrade --install helm-demo .\helm\helm-demo `
  --namespace helm-demo `
  --create-namespace `
  --wait
```

Comprueba el estado:

```powershell
helm status helm-demo --namespace helm-demo
kubectl get deployments,pods,services,configmaps -n helm-demo
kubectl get pods -n helm-demo -o wide
```

Accede a la aplicación con port-forward:

```powershell
kubectl port-forward service/helm-demo -n helm-demo 8080:80
```

Mientras el comando siga en primer plano, abre otra terminal y consulta `http://localhost:8080/` y `http://localhost:8080/health`.

### Ingress opcional

El controlador puede tardar un poco en estar listo tras habilitar el addon. Instala (o actualiza) con Ingress habilitado:

```powershell
helm upgrade --install helm-demo .\helm\helm-demo `
  --namespace helm-demo `
  --set ingress.enabled=true `
  --set ingress.host=helm-demo.local `
  --wait
kubectl get ingress -n helm-demo
```

Obtén la IP de Minikube y prueba el host sin cambiar el archivo `hosts`:

```powershell
$minikubeIp = minikube ip
curl.exe -H "Host: helm-demo.local" "http://$minikubeIp/"
```

También puedes añadir `"$minikubeIp helm-demo.local"` a `C:\Windows\System32\drivers\etc\hosts` desde una terminal elevada y abrir `http://helm-demo.local`. Si Ingress no responde, verifica que `minikube addons enable ingress` terminó y que los pods del controlador están listos con `kubectl get pods -n ingress-nginx`.

## Actualización, historial y rollback

Para que la revisión 2 use una imagen disponible en Minikube, constrúyela y cárgala primero:

```powershell
docker build -t helm-demo:2.0.0 .
minikube image load helm-demo:2.0.0
```

Actualiza a la versión 2.0.0, cambia el mensaje y aumenta las réplicas a tres:

```powershell
helm upgrade helm-demo .\helm\helm-demo `
  --namespace helm-demo `
  --set-string image.tag=2.0.0 `
  --set-string app.version=2.0.0 `
  --set-string 'app.message=Aplicación actualizada a la versión 2.0.0 con Helm' `
  --set replicaCount=3 `
  --description "Actualizando la aplicacion a 2.0.0" `
  --wait
```

Entra a la página para ver el nuevo mensaje, versión y número de pods. Consulta las revisiones:

```powershell
helm history helm-demo --namespace helm-demo
```

La revisión 1 es la instalación 1.0.0 y la revisión 2 es la actualización. La columna `APP VERSION` de `helm history` muestra el `appVersion` fijo del chart (`Chart.yaml`); la versión visible de la página procede de `app.version` en `values.yaml`. Para volver a la revisión anterior:

```powershell
helm rollback helm-demo 1 --namespace helm-demo --wait
helm history helm-demo --namespace helm-demo
kubectl get deployments,pods -n helm-demo
```

El rollback crea una nueva revisión (normalmente la 3), pero restaura la configuración de la revisión 1: versión y mensaje 1.0.0 y dos réplicas. Compruébalo en la página, manteniendo el port-forward activo.

## Diagnóstico

```powershell
kubectl get all -n helm-demo
kubectl describe deployment helm-demo -n helm-demo
kubectl describe pods -n helm-demo
kubectl logs deployment/helm-demo -n helm-demo
kubectl get events -n helm-demo --sort-by=.metadata.creationTimestamp
helm status helm-demo -n helm-demo
helm get values helm-demo -n helm-demo
helm lint .\helm\helm-demo
helm template helm-demo .\helm\helm-demo
```

Para validar el chart con Ingress habilitado sin instalarlo:

```powershell
helm template helm-demo .\helm\helm-demo --set ingress.enabled=true
```

## Eliminar los recursos

```powershell
helm uninstall helm-demo --namespace helm-demo
kubectl delete namespace helm-demo
```

La segunda orden elimina también el namespace creado para la demostración. Si quieres conservarlo, omítela.

## Git y flujo de entrega

Git guarda el historial del código y los cambios de configuración. Inicializa el repositorio local y registra la versión inicial antes de experimentar:

```powershell
git init
git add .
git commit -m "Crear ejemplo de despliegue con Helm"
```

El flujo es: Git versiona el código y el chart; Docker compila y empaqueta la aplicación; Minikube ejecuta Kubernetes local; Helm instala y actualiza los recursos, conserva el historial de releases y permite hacer rollback.

## Errores comunes

- **`dotnet` no se reconoce:** instala el SDK .NET 10 y abre una terminal nueva; valida con `dotnet --version`.
- **Docker no conecta con el daemon:** inicia Docker Desktop y espera a que el motor Linux esté listo; valida con `docker info`.
- **Minikube no inicia:** confirma Docker Desktop activo y vuelve a ejecutar `minikube start --driver=docker`; consulta `minikube status`.
- **`ImagePullBackOff`:** asegúrate de cargar exactamente el tag indicado en Helm (`minikube image load helm-demo:1.0.0`) y de usar `IfNotPresent`.
- **Pod no listo o reinicios:** inspecciona `kubectl describe pod` y `kubectl logs`; confirma el puerto 8080 y que `/health` responde.
- **Helm no encuentra el chart:** ejecuta los comandos desde la raíz y usa la ruta `.\helm\helm-demo`.
- **El servicio no responde:** espera a que `kubectl get pods -n helm-demo` muestre `Running` y `READY 1/1`; revisa el Service y deja activo `kubectl port-forward`.
- **Ingress sin respuesta:** activa el addon `minikube addons enable ingress`, espera al controlador y comprueba la IP y el host.
- **Puerto local ocupado:** cambia el puerto local del port-forward, por ejemplo `8081:80`, y abre `http://localhost:8081`.
