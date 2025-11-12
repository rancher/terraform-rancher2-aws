output "ca_certs" {
  value     = local.ca_certs
  sensitive = true
}

output "rancher_admin_password" {
  value     = random_password.admin_password.result
  sensitive = true
}
