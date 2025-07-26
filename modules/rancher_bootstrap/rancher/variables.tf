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
variable "rancher_version" {
  type        = string
  description = <<-EOT
    The version of rancher to install.
  EOT
}
variable "rancher_helm_repo" {
  type        = string
  description = <<-EOT
    The Helm repository to retrieve charts from.
  EOT
  default     = "https://releases.rancher.com/server-charts"
}
variable "rancher_helm_channel" {
  type        = string
  description = <<-EOT
    The Helm repository channel retrieve charts from.
    Can be "latest" or "stable", defaults to "stable".
  EOT
  default     = "stable"
}
variable "rancher_helm_chart_use_strategy" {
  type        = string
  description = <<-EOT
    The strategy to use for Rancher's Helm chart values.
    Options include: "default", "merge", or "provide".
    Default will tell the module to use our suggested default configuration.
    Merge will merge our default suggestions with your supplied configuration, anything you supply will override the default.
    Provide will ignore our default suggestions and use the configuration provided in the rancher_helm_chart_values argument.
  EOT
  default     = "default"
}
variable "rancher_helm_chart_values" {
  type        = string
  description = <<-EOT
    A base64 encoded, json encoded key/value map of Helm arguments to pass to the Rancher helm chart.
    This will be ignored if the rancher_helm_chart_use_strategy argument is set to "default".
    eg.
    {
      "hostname"                                            = "example.com"
      "replicas"                                            = "1"
      "bootstrapPassword"                                   = "admin"
      "ingress.enabled"                                     = "true"
      "ingress.tls.source"                                  = "letsEncrypt"
      "tls"                                                 = "ingress"
      "letsEncrypt.ingress.class"                           = "nginx"
      "letsEncrypt.environment"                             = "production"
      "letsEncrypt.email"                                   = "test@example.com"
      "certmanager.version"                                 = "1.18.1"
      "agentTLSMode"                                        = "strict"
      "privateCA"                                           = "true"
      "additionalTrustedCAs"                                = "true"
      "ingress.extraAnnotations.cert-manager\\.io\\/issuer" = "rancher"
    }
  EOT
  default     = "{}"
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
variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
  default     = "v1.13.1"
}
variable "acme_server_url" {
  type        = string
  description = <<-EOT
    The ACME server url to use for issuing certs.
  EOT
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}
