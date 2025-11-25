output "ca_certs" {
  value     = local.ca_certs
  sensitive = true
}

output "rancher_admin_password" {
  value     = local.bootstrap_password
  sensitive = true
}
