package terraform.security

deny[msg] if {
  input.resource_type == "aws_security_group"

  some i
  cidr := input.ingress[i].cidr_blocks[_]

  cidr == "0.0.0.0/0"

  msg := "No se permite acceso SSH público (0.0.0.0/0)"
}
