# infra/ — Módulo `edge` (CloudFront + S3 + WAF)

## Qué crea el módulo

| Recurso | Para qué |
|---|---|
| `aws_s3_bucket` + Block Public Access + versionado + SSE-S3 + lifecycle | Bucket privado del frontend (SPA) |
| `aws_s3_bucket_policy` | Solo **esta** distribución puede leer (`AWS:SourceArn`); niega peticiones sin TLS o con TLS menor a 1.2 |
| `aws_cloudfront_origin_access_control` | OAC: CloudFront firma con SigV4 cada petición a S3 |
| `aws_cloudfront_distribution` | Dos orígenes (S3 y API Gateway opcional), solo HTTPS, PriceClass_All, HTTP/2 y HTTP/3 |
| `aws_cloudfront_cache_policy` (catalog) | `GET /api/products*` con TTL de 60 s (máximo 300 s) |
| `aws_cloudfront_function` | Reescritura de rutas de la SPA hacia `/index.html` |
| `aws_wafv2_web_acl` (opcional) | 4 grupos de reglas administradas de AWS + límite de tasa por IP |

Comportamientos de caché, en orden de evaluación:

| Ruta | Origen | Caché |
|---|---|---|
| `/api/products*` | API Gateway | 1 a 5 min (catálogo público, solo lectura) |
| `/api/*` | API Gateway | Ninguna; reenvía el JWT (`Authorization`) |
| `*` (por defecto) | S3 | Larga (CachingOptimized) + headers de seguridad |

> Supuesto: las escrituras de administración del catálogo van por `/api/admin/*`, que cae en el comportamiento sin caché.

## Pruebas locales

Ninguno de estos comandos crea recursos ni necesita credenciales de AWS.

```sh
cd infra/modules/edge

terraform init
terraform fmt -check -recursive
terraform validate
terraform test        # 4 pruebas con mock_provider
```

Resultado esperado de `terraform test`:

```
tests/edge.tftest.hcl... in progress
  run "solo_frontend"... pass
  run "frontend_api_y_waf"... pass
  run "dominio_sin_certificado_falla"... pass
  run "entorno_invalido_falla"... pass
tests/edge.tftest.hcl... tearing down
tests/edge.tftest.hcl... pass

Success! 4 passed, 0 failed.
```

Validación de los entornos:

```sh
cd ../../envs/dev
terraform init -backend=false
terraform validate

cd ../prod
terraform init -backend=false
terraform validate
```

Escaneo de seguridad (opcional, requiere Python), desde la raíz del repositorio:

```sh
pip install checkov
checkov -d infra --framework terraform --compact
```

## Costos

| Comando | ¿Toca AWS? | ¿Costo? |
|---|---|---|
| `init`, `fmt`, `validate` | No | 0 |
| `test` | No, usa `mock_provider` | 0 |
| `plan` | Solo lectura, requiere credenciales | 0 |
| `apply` | Crea recursos reales | Sí |

## Decisiones de diseño

- **El módulo no declara `provider`:** lo recibe del entorno, así se reutiliza en cualquier cuenta o región.
- **dev y prod solo cambian `terraform.tfvars`:** dev sin WAF y con `force_destroy`; prod con WAF y protegido contra borrado.
- **OAC en lugar de OAI:** OAC es el método actual, firma con SigV4 y soporta SSE-KMS y todas las regiones.
- **CloudFront Function en lugar de `custom_error_response`:** reescribir los 403/404 a `index.html` también ocultaría los errores reales del API. La función solo corre en el comportamiento del frontend.
- **Políticas administradas buscadas por nombre** (data sources), no IDs copiados a mano.
- **`stale-if-error`:** lo envía la Lambda en `Cache-Control`; CloudFront lo respeta y sigue sirviendo el catálogo si el origen falla.
- **Sin dominio propio (supuesto):** se usa `*.cloudfront.net`. Con `aliases` + `acm_certificate_arn`, el módulo cambia a SNI y TLSv1.2_2021. Una `precondition` impide definir un dominio sin certificado.
- **Excepciones de Checkov:** cada `#checkov:skip` tiene su justificación en el código (logs, replicación y failover quedan fuera de la v1 por costo o alcance).
