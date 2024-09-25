output "kubeconfig" {
  value       = module.cluster.kubeconfig
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}

output "address" {
  value = "https://${local.project_domain}.${local.zone}"
}

output "admin_token" {
  value     = module.rancher_bootstrap.admin_token
  sensitive = true
}

output "admin_password" {
  value     = module.rancher_bootstrap.admin_password
  sensitive = true
}
