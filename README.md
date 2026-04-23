# AUY1105 - Infraestructura como Código

## Objetivo
Implementar infraestructura en AWS usando Terraform con validación automática de calidad y seguridad mediante GitHub Actions.

## Infraestructura
- VPC: 10.1.0.0/16
- Subnet: 10.1.1.0/24
- EC2: t2.micro Ubuntu 24.04
- Security Group: acceso controlado SSH

## Pipeline CI/CD
El pipeline ejecuta:

1. TFLint → análisis estático
2. Checkov → análisis de seguridad
3. OPA → validación de políticas
4. Terraform Validate → verificación final

## Políticas de seguridad
- No se permite acceso SSH público (0.0.0.0/0)
- Solo instancias EC2 tipo t2.micro

## Herramientas usadas
- Terraform
- AWS
- GitHub Actions
- TFLint
- Checkov
- OPA
