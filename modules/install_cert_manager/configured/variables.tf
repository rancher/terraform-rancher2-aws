variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert manager to install.
  EOT
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
    https://docs.aws.amazon.com/sdkref/latest/guide/environment-variables.html
  EOT
  sensitive   = true
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
