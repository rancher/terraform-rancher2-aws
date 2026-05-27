# tflint-ignore: terraform_unused_declarations
variable "aws_region" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "identifier" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "owner" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "rancher_address" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "rancher_admin_password" {
  type      = string
  sensitive = true
}
# tflint-ignore: terraform_unused_declarations
variable "rancher_admin_token" {
  type      = string
  sensitive = true
}
# tflint-ignore: terraform_unused_declarations
variable "tls_certificate_chain" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "node_config_name" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "aws_access_key_id" {
  type      = string
  sensitive = true
}
# tflint-ignore: terraform_unused_declarations
variable "aws_secret_access_key" {
  type      = string
  sensitive = true
}
# tflint-ignore: terraform_unused_declarations
variable "aws_session_token" {
  type      = string
  sensitive = true
}
# tflint-ignore: terraform_unused_declarations
variable "aws_region_letter" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "downstream_security_group_name" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "vpc_id" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "load_balancer_security_group_id" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "subnet_id" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "node_info" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "runner_ip" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "ssh_access_key" {
  type      = string
  sensitive = true
}
# tflint-ignore: terraform_unused_declarations
variable "ssh_access_user" {
  type = string
}
# tflint-ignore: terraform_unused_declarations
variable "rke2_version" {
  type = string
}
