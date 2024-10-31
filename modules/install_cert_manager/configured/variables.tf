variable "zone" {
  type        = string
  description = <<-EOT
    The zone within the domain.
    eg. if the domain is "test.example.com", then this should be "example.com"
  EOT
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
