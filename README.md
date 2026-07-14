# Documentación Técnica de Laboratorio Día 1

****Título:**** Infraestructura Base en AWS, Seguridad Avanzada IAM (`iam:PassRole` + `sts:AssumeRole`), Redes VPC y Cómputo con AWS Systems Manager (SSM).

## 1\. Resumen Ejecutivo y Objetivos

El objetivo principal de este laboratorio fue diseñar, aprovisionar y validar una infraestructura en AWS aplicando el ****Principio de Mínimo Privilegio**** y automatización mediante ****Infraestructura como Código (Terraform)****.

Se demostró el flujo completo de despliegue donde un operador/pipeline no utiliza permisos de Administrador ni claves estáticas de largo plazo, sino que asume dinámicamente un rol restringido (`DeployerRole`) para aprovisionar capacidad de cómputo, requiriendo autorización explícita (`iam:PassRole`) para delegar identidades a servicios de AWS.

## 2\. Diagrama de Arquitectura y Flujo Lógico

1.  ****Fase IaC (Terraform):**** Se aprovisiona la VPC, subred pública, S3 bucket, Security Group e Identidades de IAM (`AppServerRole`, `AppServerInstanceProfile` y `DeployerRole`).
2.  ****Fase STS (******`**sts:AssumeRole**`******):**** El usuario CLI solicita credenciales temporales de STS para convertirse en `DeployerRole`.
3.  ****Fase EC2 API (******`**iam:PassRole**`******):**** Con la identidad de `DeployerRole`, se invoca `ec2:RunInstances` pasando el `AppServerInstanceProfile`. AWS verifica que `DeployerRole` tenga autorización `iam:PassRole` sobre `AppServerRole`.
4.  ****Fase Operaciones (SSM Session Manager):**** Se establece sesión SSH-less vía Systems Manager hacia la EC2 y se valida el acceso de solo lectura al bucket S3 usando la identidad del rol nativo del servidor.

## 3\. Desglose Teórico de Componentes y Conceptos Clave

### A. AWS Security Token Service (STS) y Credenciales Temporales

-   ****¿Qué es STS?**** Es un servicio web de AWS que permite solicitar credenciales temporales y con tiempo de expiración acotado (por defecto 1 hora) para usuarios IAM o identidades federadas.
-   ****Credenciales de Sesión:**** Compuestas por tres elementos indisolubles:
-   1.  `AWS_ACCESS_KEY_ID`: Inicia con la sigla **`**ASIA...**`** (a diferencia de las llaves estáticas de IAM que inician con `AKIA...`).
    2.  `AWS_SECRET_ACCESS_KEY`: Clave secreta temporal.
    3.  `AWS_SESSION_TOKEN`: Token criptográfico obligatorio que valida la sesión en la API. Si se omite, AWS rechaza la petición con un error `AuthFailure`.

### B. El Mecanismo `iam:PassRole` y Prevención de Escalado de Privilegios

-   ****El Riesgo de Seguridad (Privilege Escalation):**** Si un desarrollador tiene permisos para crear instancias (`ec2:RunInstances`), podría adjuntar a esa instancia un rol con permisos de `AdministratorAccess`, ingresar a la instancia y tomar control absoluto de la cuenta de AWS.
-   ****La Solución (******`**iam:PassRole**`******):**** `PassRole` no es una llamada a la API que se ejecute activamente; es una ****comprobación de autorización de IAM****. Cuando la API de EC2 intenta asociar un Instance Profile a un servidor, IAM evalúa si el usuario o pipeline que invoca la orden posee el permiso `iam:PassRole` limitado al ARN específico del rol que pretende asignar.

### C. IAM Role vs. IAM Instance Profile

-   ****IAM Role:**** Objeto de IAM que define un conjunto de permisos (Policy) y quién puede asumirlo (Trust Policy). Es una entidad lógica pura.
-   ****Instance Profile:**** Contenedor específico del servicio EC2 que alberga exactamente un IAM Role. Actúa como el puente físico que expone las credenciales temporales del rol al metadato de la instancia (****IMDS - Instance Metadata Service****).

### D. Conectividad Segura mediante AWS Systems Manager (SSM)

-   ****Eliminación de Bastion Hosts y Llaves .pem:**** SSM Session Manager abre un túnel cifrado en la capa de aplicación sin necesidad de abrir el puerto 22 de entrada (Ingress) en los Security Groups ni asociar pares de claves SSH.
-   ****Requisito de Red y Permisos:**** La EC2 necesita salida a Internet hacia el endpoint de SSM (`ssm.<region>.amazonaws.com` en puerto 443) y la política administrada `AmazonSSMManagedInstanceCore` adjunta a su rol.
