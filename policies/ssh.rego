package terraform.security

deny[msg] {
  input.resource_type == "aws_security_group"

  ingress := input.ingress[_]
  cidr := ingress.cidr_blocks[_]

  cidr == "0.0.0.0/0"

  msg = "No se permite acceso SSH público (0.0.0.0/0)"
}
