variable "path" {
  description = "The root path where files will be deployed from"
  type        = string
}
variable "rancher_domain" {
  description = "The domain name to use for Rancher"
  type        = string
}
variable "ca_certs" {
  description = "The CA certificates to trust when accessing Rancher"
  type        = string
}
variable "admin_password" {
  description = "The initial admin password for Rancher"
  type        = string
  sensitive   = true
}
