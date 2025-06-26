output "admin_token" {
  value     = module.deploy_rancher.output.admin_token
  sensitive = true
}

output "admin_password" {
  value     = module.deploy_rancher.output.admin_password
  sensitive = true
}
