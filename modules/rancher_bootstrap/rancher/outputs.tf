output "admin_token" {
  value     = rancher2_bootstrap.admin.token
  sensitive = true
}

output "admin_password" {
  value     = random_password.password.result
  sensitive = true
}

output "ca_certs" {
  value     = data.kubernetes_secret_v1.certificate.data["tls.crt"]
  sensitive = true
}
