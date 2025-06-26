variable "project_domain" {
  type        = string
  description = <<-EOT
    The project domain. An fqdn, eg. "test.example.com".
  EOT
  validation {
    condition = can(regex(
      "^(?:https?://)?[[:alpha:]](?:[[:alnum:]\\p{Pd}]{1,63}\\.)+[[:alnum:]\\p{Pd}]{1,62}[[:alnum:]](?::[[:digit:]]{1,5})?$",
      var.project_domain
    ))
    error_message = "Must be a fully qualified domain name."
  }
}
variable "zone_id" {
  type        = string
  description = <<-EOT
    The ID of the zone within the domain.
    eg. if the domain is "test.example.com", then the zone should be "example.com"
    The AWS ID of that zone.
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
variable "acme_server_url" {
  type        = string
  description = <<-EOT
    The ACME server url to use for issuing certs.
  EOT
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}
variable "rancher_version" {
  type        = string
  description = <<-EOT
    The version of rancher to install.
  EOT
  default     = "2.11.2"
}
variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
  default     = "v1.13.1"
}
variable "externalTLS" {
  type        = bool
  description = <<-EOT
    Whether or not to use Cert Manager for Rancher's TLS.
    If true, this assumes you have saved the external certificate in the "tls-rancher-ingress" kubernetes secret.
  EOT
  default     = true
}
variable "path" {
  type        = string
  description = <<-EOT
    The local file path to stage files for the deployment.
  EOT
}
