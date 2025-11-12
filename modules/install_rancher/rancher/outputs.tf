output "ca_certs" {
  value     = data.kubernetes_secret_v1.certificate.data["tls.crt"]
  sensitive = true
}

output "rancher_admin_password" {
  value     = random_password.admin_password.result
  sensitive = true
}
