variable "project_domain" {
  type        = string
  description = <<-EOT
    The project domain. An fqdn, eg. "test.example.com".
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
    aws_access_key_id     = string
    aws_secret_access_key = string
    aws_region            = string
    email                 = string
  })
  description = <<-EOT
    The AWS access key information necessary to configure cert-manager.
    This should have the limited access as found in the cert-manager documentation.
    https://cert-manager.io/docs/configuration/acme/dns01/route53/#iam-user-with-long-term-access-key
    This is an optional parameter, when not specified we will use the certificate that was generated with the project.
  EOT
  default = {
    aws_access_key_id     = ""
    aws_secret_access_key = ""
    aws_region            = ""
    email                 = ""
  }
  sensitive = true
}
