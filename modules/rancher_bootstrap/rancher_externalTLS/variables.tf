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
  default     = "2.11.2"
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
  type        = map(any)
  description = <<-EOT
    A key/value map of Helm arguments to pass to the Rancher helm chart.
    This will be ignored if the rancher_helm_chart_use_strategy argument is set to "default".
    eg.
    {
      "hostname"                  = local.rancher_domain
      "replicas"                  = "1"
      "bootstrapPassword"         = "admin"
      "ingress.enabled"           = "true"
      "ingress.tls.source"        = "secret"
      "ingress.tls.secretName"    = "tls-rancher-ingress"
      "privateCA"                 = "true"
      "agentTLSMode"              = "system-store"
    }
  EOT
  default     = {}
}
