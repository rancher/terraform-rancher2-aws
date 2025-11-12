output "ca_certs" {
  value     = module.deploy_rancher.output.ca_certs
  sensitive = true
}

output "rancher_admin_password" {
  value     = module.deploy_rancher.output.rancher_admin_password
  sensitive = true
}
