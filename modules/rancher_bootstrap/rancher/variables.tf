variable "project_domain" {
  type        = string
  description = <<-EOT
    The project domain. An fqdn, eg. "test.example.com".
  EOT
}
variable "zone" {
  type        = string
  description = <<-EOT
    The zone within the domain.
    eg. if the domain is "test.example.com", then this should be "example.com"
  EOT
}
variable "zone_id" {
  type        = string
  description = <<-EOT
    The ID of the zone within the domain.
    eg. if the domain is "test.example.com", then the zone should be "example.com"
    The ID of that zone.
  EOT
}
variable "region" {
  type        = string
  description = <<-EOT
    The AWS region for cert manager to validate certificates.
  EOT
}
variable "email" {
  type        = string
  description = <<-EOT
    The email to use when registering an account with Let's Encrypt.
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
variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
  default     = "v1.13.1"
}
variable "cert_manager_configuration" {
  type = object({
    aws_region            = string
    aws_session_token     = string
    aws_access_key_id     = string
    aws_secret_access_key = string
  })
  description = <<-EOT
    The AWS access key information necessary to configure cert-manager.
    These will be added as environment variables to configure Cert Manager Ambient Credentials.
    https://cert-manager.io/docs/configuration/acme/dns01/route53/#ambient-credentials
  EOT
  default = {
    aws_region            = ""
    aws_session_token     = ""
    aws_access_key_id     = ""
    aws_secret_access_key = ""
  }
  sensitive = true
}
variable "acme_server_url" {
  type        = string
  description = <<-EOT
    The ACME server url to use for issuing certs.
  EOT
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}
