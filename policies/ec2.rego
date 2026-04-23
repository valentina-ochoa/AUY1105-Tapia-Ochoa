package terraform.security

deny[msg] {
  input.resource_type == "aws_instance"
  input.instance_type != "t2.micro"
  msg = "Solo se permite EC2 tipo t2.micro"
}
