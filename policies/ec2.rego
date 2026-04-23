package terraform.security

deny[msg] {
  input.instance_type != "t2.micro"
  msg = "Solo t2.micro permitido"
}
