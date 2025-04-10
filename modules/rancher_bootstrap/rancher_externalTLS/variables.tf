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
