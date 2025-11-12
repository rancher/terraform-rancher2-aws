output "admin_password" {
  value     = rancher2_bootstrap.admin.password
  sensitive = true
}
output "admin_token" {
  value     = rancher2_bootstrap.admin.token
  sensitive = true
}
