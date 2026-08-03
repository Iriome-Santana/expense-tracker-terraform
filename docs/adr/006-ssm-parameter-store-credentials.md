# ADR-006: SSM Parameter Store para credenciales de producción

## Contexto

Las credenciales de la base de datos (`DB_PASSWORD`) se pasaban como variables 
de Terraform al `user_data` del EC2, donde se escribían en un archivo `.env` 
en texto plano. Este patrón tiene dos problemas de seguridad:

1. Las credenciales aparecen en el Terraform state, que vive en S3
2. El `user_data` es accesible desde dentro de la instancia via el metadata 
   endpoint (`169.254.169.254`), lo que las expone ante un ataque SSRF

## Decisión

Migrar las credenciales sensibles a AWS SSM Parameter Store como `SecureString`, 
encriptadas con KMS. El `user_data` las fetcha en runtime usando el IAM Instance 
Profile — sin que ninguna credencial viaje como variable de Terraform ni quede 
en el state.

## Alternativas consideradas

**AWS Secrets Manager** — ofrece rotación automática de credenciales integrada, 
pero cuesta 0.40$/mes por secret. Para un proyecto con un único secret estático 
que no requiere rotación automática, el coste no está justificado. SSM Parameter 
Store cubre el mismo caso de uso de forma gratuita.

**Variables de entorno en el IAM role** — no existe este mecanismo en AWS. Las 
credenciales tienen que llegar al proceso de alguna forma; SSM es el canal correcto.

## Consecuencias

- `db_password` eliminada de `variables.tf` y `terraform.tfvars`
- El IAM Instance Profile ya tenía `AmazonSSMManagedInstanceCore` — no fue 
  necesario añadir permisos adicionales
- Cada acceso al parámetro queda auditado automáticamente en CloudTrail
- La migración requirió backup previo de PostgreSQL, destrucción y recreación 
  de la instancia, y restauración desde S3 — proceso documentado como referencia 
  para futuros cambios que requieran downtime controlado

## Estado

Implementado — Junio 2026