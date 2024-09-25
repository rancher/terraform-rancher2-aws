output "admin_token" {
  value     = data.external.output.result.admin_token
  sensitive = true
}

output "admin_password" {
  value     = data.external.output.result.admin_password
  sensitive = true
}

