package terraform.security

deny[msg] {
  input.resource_changes[_].type == "aws_instance"

  instance_type := input.resource_changes[_].change.after.instance_type
  instance_type != "t3.micro"

  msg = "ERROR: Solo se permite EC2 tipo t3.micro"
}
