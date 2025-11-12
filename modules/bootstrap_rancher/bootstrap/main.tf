locals {
  rancher_domain = var.rancher_domain
  ca_certs       = base64decode(var.ca_certs)
  admin_password = var.admin_password
}

provider "rancher2" {
  api_url   = "https://${local.rancher_domain}"
  bootstrap = true
  ca_certs  = local.ca_certs
  timeout   = "300s"
}

resource "rancher2_bootstrap" "admin" {
  initial_password = local.admin_password
  password         = local.admin_password
  token_update     = true
  token_ttl        = 7200 # 2 hours
}
