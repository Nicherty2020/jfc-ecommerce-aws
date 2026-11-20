# Estimación de costos — en construcción

Aquí irán el enlace compartido de la Calculadora de Precios de AWS y su exportación, con tres escenarios: valle, pico y estrés.

Factores de costo (sección 10.1 del documento de arquitectura):

- **Fijos pequeños:** llave de KMS y secretos de Secrets Manager. El plan Free de CloudFront incluye WAF, la zona de Route 53 y el certificado TLS.
- **Variables:** peticiones de API Gateway, ejecuciones de Lambda, lecturas y escrituras de DynamoDB, mensajes de SQS y EventBridge, correos de SES, logs y trazas.
- **Excluidos a propósito (costo fijo):** NAT Gateway, ElastiCache, Aurora, ALB y ECS.
