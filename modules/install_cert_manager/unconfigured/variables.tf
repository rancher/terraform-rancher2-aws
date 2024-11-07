variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
  default     = "v1.13.1"
}
variable "project_cert_key_id" {
  type        = string
  description = <<-EOT
    The key name to retrieve the project's cert's private key from AWS
  EOT
  default     = ""
}
variable "project_cert_name" {
  type        = string
  description = <<-EOT
    The project's cert name
  EOT
  default     = ""
}
