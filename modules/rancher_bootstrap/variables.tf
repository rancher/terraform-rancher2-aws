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
  default     = "https://releases.rancher.com/server-charts/latest"
}
variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
  default     = "v1.11.0"
}
