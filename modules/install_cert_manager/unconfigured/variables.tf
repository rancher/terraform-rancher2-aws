variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
}
variable "project_cert_key_id" {
  type        = string
  description = <<-EOT
    The key name to retrieve the project's cert's private key from AWS
  EOT
}
variable "project_cert_name" {
  type        = string
  description = <<-EOT
    The project's cert name
  EOT
}
