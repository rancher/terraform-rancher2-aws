variable "project_domain" {
  type        = string
  description = <<-EOT
    The project domain.
  EOT
}
variable "rancher_version" {
  type        = string
  description = <<-EOT
    The version of rancher to install.
  EOT
  default     = "2.8.4"
}
variable "rancher_helm_repository" {
  type        = string
  description = <<-EOT
    The helm repository to install rancher from.
  EOT
  default     = "https://releases.rancher.com/server-charts/stable"
}
variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
  default     = "v1.13.1"
}
variable "project_cert_name" {
  type        = string
  description = <<-EOT
    The project's cert name
  EOT
  default     = ""
}
variable "project_cert_key_id" {
  type        = string
  description = <<-EOT
    The key name to retrieve the project's cert's private key from AWS
  EOT
  default     = ""
}
variable "path" {
  type        = string
  description = <<-EOT
    The path where we will place the terraform config to deploy.
  EOT
  default     = ""
}
