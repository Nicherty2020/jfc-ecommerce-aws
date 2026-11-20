# infra/ — IaC del e-commerce JFC (arquitectura v1)

Terraform para la arquitectura serverless v1: borde, identidad, API, microservicios, eventos, datos, seguridad, observabilidad y CI/CD. dev y prod viven en la **misma cuenta** de AWS (supuesto) y en us-east-1.

## Estructura

```
infra/
  bootstrap/            Bucket del estado de Terraform (estado local, se aplica una vez)
  global/               Lo que existe una vez por cuenta: OIDC de GitHub, CloudTrail,
                        Budgets, SES, alarma de concurrencia, bucket de artefactos
  modules/
    ecommerce/          Composición de un entorno completo (lo usan dev y prod)
    platform/           Llave KMS, bus de EventBridge y tema SNS de alarmas
    identity/           Cognito (user pool, grupo admin, cliente de la SPA)
    microservice/       Lambda + rol + logs + alias + tabla + colas/DLQ + reglas + alarmas
    api/                API Gateway REST (Cognito, throttling, webhook directo a SQS)
    edge/               CloudFront + S3 + WAF + ACM + Route 53
    observability/      Alarma de 5XX de la API y el dashboard
    private-bucket/     Bucket S3 privado con los controles base
  envs/
    dev/  prod/         Solo cambian terraform.tfvars
```

El módulo `microservice` es la pieza reutilizable principal: el mismo módulo se usa seis veces, una por servicio, y cada uso recibe solo sus permisos.

## Qué crea, por sección del documento de arquitectura

| Sección | Dónde | Recursos |
|---|---|---|
| 6.1 Borde | `edge` | CloudFront con plan Free (2 orígenes, caché por ruta, PriceClass_All), WAF (4 grupos administrados + tasa por IP sin el webhook), S3 con OAC, ACM y alias A/AAAA en Route 53 si hay dominio |
| 6.2 Identidad | `identity` | User pool (login por email, MFA TOTP opcional), grupo `admin`, cliente público para la SPA (SRP) |
| 6.3 API | `api` | API REST regional, API key que inyecta CloudFront, autorizador de Cognito, access logs, X-Ray, throttling, `POST /api/payments/webhook` → SQS sin Lambda |
| 6.3 Cómputo | `microservice` | Lambda arm64 fuera de VPC, X-Ray, alias `live`, concurrencia reservada en Pedidos e Inventario |
| 6.4 Datos | `microservice` | Tabla on-demand por servicio con PITR, protección contra borrado, CMK y TTL |
| 6.5 Integración | `platform`, `microservice` | Bus `jfc-<env>-ecommerce`, una regla y una cola con DLQ por consumidor, regla programada cada 5 min |
| 6.5 Correo | `global`, `microservice` | Identidad de SES (dominio con DKIM, o un correo) y permiso de envío solo para Notificaciones |
| 6.6 Seguridad | `platform`, `ecommerce`, `global` | CMK con rotación, secreto de la pasarela, un rol IAM por función, CloudTrail |
| 6.7 Observabilidad | `microservice`, `observability`, `global` | Alarmas de la sección 12, dashboard, SNS por correo, Budgets 80 % y 100 % |
| 6.8 CI/CD | `global`, `.github/workflows` | Proveedor OIDC, rol de plan (PR) y un rol de deploy por entorno, bucket de artefactos, pruebas de humo |

### Microservicios y eventos

| Servicio | Tabla | API | Consume (cola) | Publica |
|---|---|---|---|---|
| catalog | sí | `GET /api/products`, `GET /api/products/{id}`, `/api/admin/*` | — | — |
| users | sí | `GET/PUT /api/me` | — | — |
| orders | sí (+ índice `por-estado`) | `POST /api/orders`, `GET /api/orders/{id}` | StockRejected, PaymentReady, PaymentApproved, PaymentFailed | OrderCreated, OrderConfirmed, OrderCancelled |
| inventory | sí | — | OrderCreated, OrderConfirmed, OrderCancelled | StockReserved, StockRejected |
| payments | sí | webhook (vía SQS) | StockReserved + cola `webhook` | PaymentReady, PaymentApproved, PaymentFailed |
| notifications | no | — | OrderConfirmed, OrderCancelled | — |

El vencimiento de pedidos (cada 5 minutos) invoca la misma Lambda de Pedidos, porque escribe en su tabla. Pedidos obtiene el precio invocando el alias `live` de Catálogo (D12).

### Alarmas (todas avisan por correo vía SNS)

| Alarma | Dónde | Condición |
|---|---|---|
| 5XX de API Gateway | `observability` | > 1 % en 5 min |
| Errores de Lambda del checkout (orders, inventory, payments) | `microservice` | > 0 |
| Throttles de Lambda | `microservice` | > 0 |
| Throttles de DynamoDB (lectura + escritura) | `microservice` | > 0 |
| Mensajes en una DLQ | `microservice` | > 0 |
| Mensajes atrasados en SQS | `microservice` | edad > 5 min |
| Pago tras cancelación (`PaymentNeedsRefund`) | `observability` | > 0 |
| Concurrencia de Lambda de la cuenta | `global` | ≥ 80 % de la cuota |
| AWS Budgets | `global` | 80 % y 100 % |

## Primer despliegue

Requisitos: Terraform ≥ 1.11 (bloqueo nativo del estado en S3) y credenciales de administrador para los pasos 1 y 2.

1. **Bootstrap** (una vez, estado local):
   ```sh
   cd infra/bootstrap
   terraform init && terraform apply
   ```
2. **Global** (una vez por cuenta). Editar `global/terraform.tfvars` y luego:
   ```sh
   cd infra/global
   terraform init -backend-config="bucket=jfc-tfstate-<ID_CUENTA>"
   terraform apply
   ```
3. **GitHub**. En *Settings > Environments*, crear `dev` y `prod`, ambos con *Deployment branches* = solo `main`; `prod` además con *Required reviewers* (es la aprobación manual). Luego las variables:

   | Variable | Dónde | Valor |
   |---|---|---|
   | `AWS_PLAN_ROLE_ARN` | Repositorio | output `github_plan_role_arn` |
   | `TF_STATE_BUCKET` | Repositorio | output `tfstate_bucket` de bootstrap |
   | `ARTIFACTS_BUCKET` | Repositorio | output `artifacts_bucket` |
   | `AWS_DEPLOY_ROLE_ARN` | Environment `dev` | output `github_deploy_role_arns["dev"]` |
   | `AWS_DEPLOY_ROLE_ARN` | Environment `prod` | output `github_deploy_role_arns["prod"]` |
4. **Entornos**: editar `envs/<env>/terraform.tfvars` y hacer merge a `main`. El workflow `deploy` aplica dev, corre las pruebas de humo, espera la aprobación y aplica prod. Las pruebas de humo exigen 200 en el sitio y en `/api/products`, y 403 en la URL `execute-api` directa (D10).
5. **Secreto de la pasarela** (fuera de Terraform, para que no quede en el estado):
   ```sh
   aws secretsmanager put-secret-value --secret-id jfc-prod/payments/gateway \
     --secret-string '{"api_key":"...","webhook_secret":"..."}'
   ```

## Pasos manuales (no se automatizan)

- MFA en la cuenta root y ningún usuario IAM con llaves de acceso.
- Confirmar las suscripciones de correo de SNS (llega un enlace).
- Verificar el correo de SES si no hay dominio, y pedir la **salida del sandbox** de SES antes de producción.
- Revisar en Service Quotas la concurrencia de Lambda y pedir el aumento: prod reserva 150 ejecuciones y la cuenta debe dejar al menos 100 sin reservar.
- Cargar el valor del secreto de la pasarela (paso 5).

## Pruebas locales

Ninguno de estos comandos crea recursos ni necesita credenciales.

```sh
terraform fmt -check -recursive infra

# Pruebas con mock_provider
for m in api edge microservice ecommerce; do
  terraform -chdir=infra/modules/$m init -backend=false
  terraform -chdir=infra/modules/$m test
done

# Validación de las raíces
for r in bootstrap global envs/dev envs/prod; do
  terraform -chdir=infra/$r init -backend=false
  terraform -chdir=infra/$r validate
done
```

| Módulo | Pruebas |
|---|---|
| `api` | 1: todas las rutas exigen la API key de CloudFront, las privadas además Cognito, el webhook solo escribe en su cola |
| `edge` | 7: solo frontend, frontend + API + WAF + API key + plan Free, dominio propio, API sin API key (falla), plan sin WAF (falla), dominio sin zona (falla), entorno inválido (falla) |
| `microservice` | 4: servicio del checkout, servicio de solo lectura, servicio sin tabla, nombre inválido (falla) |
| `ecommerce` | 3: entorno dev completo, prod con dominio, dominio sin zona (falla) |

| Comando | ¿Toca AWS? | ¿Costo? |
|---|---|---|
| `init`, `fmt`, `validate`, `test` | No | 0 |
| `plan` | Solo lectura, requiere credenciales | 0 |
| `apply` | Crea recursos reales | Sí |

## Decisiones de diseño

- **Misma cuenta para dev y prod:** lo que existe una vez por cuenta (OIDC, CloudTrail, Budgets, SES, ajuste de logs de API Gateway, alarma de concurrencia) vive en `global/`; el resto lleva el prefijo `jfc-<env>-`.
- **Tres roles de GitHub:** `jfc-github-plan` (solo pull requests, `ReadOnlyAccess` sin lectura de datos de negocio) y un rol de despliegue por entorno, `jfc-github-deploy-dev` y `jfc-github-deploy-prod`. Cada uno solo lo asume su environment de GitHub, que a su vez solo acepta `main`. Usan `PowerUserAccess` + IAM limitado a los roles de su entorno (`jfc-dev-*` o `jfc-prod-*`), y niegan todo recurso con la etiqueta `Environment` del otro entorno y su estado de Terraform. Como comparten cuenta, el aislamiento completo llega con una cuenta por entorno (D14).
- **Terraform crea la infraestructura; el pipeline despliega el código:** cada Lambda nace con un código de relleno y el alias `live`. El pipeline sube el paquete, publica una versión y mueve el alias. Terraform ignora el código y la versión del alias. Rollback = mover el alias (workflow `rollback`).
- **Webhook sin Lambda en la entrada:** API Gateway escribe el cuerpo crudo en SQS y responde 200; si SQS falla responde 500 y la pasarela reintenta. La firma se valida después, en la Lambda de Pagos.
- **Ningún evento se pierde sin aviso:** si la Lambda falla, SQS reintenta y deja el mensaje en la DLQ; si EventBridge no logra entregar a la cola, lo deja en la misma DLQ. Hay alarma con cualquier mensaje en una DLQ.
- **KMS y EventBridge:** la política de la llave permite a `events.amazonaws.com` cifrar, porque las colas están cifradas con la CMK. Sin ese permiso las entregas fallan.
- **Concurrencia reservada y colas:** en prod, Pedidos reserva 100 e Inventario 50. Cada cola tiene un tope de lectores menor que la reserva para que los mensajes no reboten por throttling y terminen en la DLQ.
- **Rutas bajo `/api`:** CloudFront reenvía `/api/*` tal cual y agrega el stage (`/v1`) como `origin_path`. Como el navegador y la API comparten dominio, no hace falta CORS.
- **Origen de la API cerrado (D10):** CloudFront envía una `x-api-key` secreta como cabecera de origen y todas las rutas de API Gateway la exigen. Quien llame la URL `execute-api` directo recibe 403, así nadie se salta el WAF ni la caché. La API key no autentica usuarios (eso lo hace Cognito); solo cierra el origen.
- **CloudFront con plan Free (D11):** `aws_pricingplanmanager_subscription` suscribe la distribución y su WAF al plan (el plan exige un WAF asociado y admite hasta 5 reglas: 4 administradas + tasa). El plan no permite políticas de caché propias, así que el catálogo usa `CachingOptimized` y su TTL lo fija el `max-age` que envía Catálogo (S11).
- **La tasa por IP excluye el webhook:** la pasarela llama desde pocas IPs y no debe quedar bloqueada.
- **Precio desde Catálogo (D12):** Pedidos invoca el alias `live` de Catálogo con `lambda:InvokeFunction`, sin pasar por CloudFront. Así no lee la tabla de otro servicio y no se forma un ciclo de dependencias entre la Lambda, la API y la distribución.
- **Dominio propio opcional:** con `domain_name` + `hosted_zone_name` se crean el certificado ACM y los alias; CloudFront exige TLS 1.2. Sin dominio se usa `*.cloudfront.net`.
- **Secretos fuera del estado:** Terraform crea el secreto vacío y el valor se carga aparte.
- **Políticas IAM con `jsonencode`:** se leen como el JSON final y funcionan con `mock_provider` en las pruebas.
- **OAC en lugar de OAI** y **CloudFront Function en lugar de `custom_error_response`** para la SPA, como en la versión anterior del módulo `edge`.

## Supuestos de la IaC (ajustables)

- Runtime de las Lambdas: Python 3.13, handler `app.handler`, Powertools empaquetado con el código.
- Código en `services/<servicio>/` y SPA en `frontend/` con `npm run build` → `dist/`.
- Claves genéricas `pk`/`sk` en las tablas; los registros de idempotencia de Powertools viven en la misma tabla con TTL en `expiration`.
- La firma del webhook viene en el cuerpo (Wompi). Para Stripe, `webhook_signature_header = "Stripe-Signature"`.
- Las métricas de negocio (`OrderCreated`, `OrderConfirmed`, `OrderCancelled`, `PaymentNeedsRefund`) las publica la Lambda de Pedidos con Powertools Metrics; son métricas personalizadas con costo por métrica.
- El catálogo no usa query strings (`GET /api/products` y `GET /api/products/{id}`): `CachingOptimized` no las incluye en la clave de caché.
