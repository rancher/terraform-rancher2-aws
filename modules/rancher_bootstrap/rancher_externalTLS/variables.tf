variable "project_domain" {
  type        = string
  description = <<-EOT
    The project domain. An fqdn, eg. "test.example.com".
  EOT
}
variable "rancher_version" {
  type        = string
  description = <<-EOT
    The version of rancher to install.
  EOT
  default     = "2.9.2"
}
variable "rancher_helm_repository" {
  type        = string
  description = <<-EOT
    The helm repository to install rancher from.
  EOT
  default     = "https://releases.rancher.com/server-charts/stable"
}
