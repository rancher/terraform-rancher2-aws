variable "rancher_domain" {
  description = "The domain name for the Rancher server"
  type        = string
}

variable "ca_certs" {
  description = "Base64 encoded CA certificate chain to trust when connecting to the Rancher server"
  type        = string
  default     = ""
}

variable "admin_password" {
  description = "The initial admin password for the Rancher server"
  type        = string
}
