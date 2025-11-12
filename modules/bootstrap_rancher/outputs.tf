output "admin_token" {
  value     = module.bootstrap.output.admin_token
  sensitive = true
}

output "admin_password" {
  value     = module.bootstrap.output.admin_password
  sensitive = true
}
