package terraform.security

deny[msg] {
  input.resource_changes[_].type == "aws_security_group"

  some i
  cidr := input.resource_changes[_].change.after.ingress[i].cidr_blocks[_]

  cidr == "0.0.0.0/0"

  msg = "ERROR: SSH público (0.0.0.0/0) no permitido"
}
