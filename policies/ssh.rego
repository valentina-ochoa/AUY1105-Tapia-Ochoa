package terraform.security

deny[msg] {
  input.ingress[_].cidr_blocks[_] == "0.0.0.0/0"
  msg = "SSH público no permitido"
}
