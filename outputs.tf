output "kubeconfig" {
  value       = module.cluster.kubeconfig
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}

output "address" {
  value = "https://${local.domain}.${local.zone}"
}

output "admin_token" {
  value     = module.rancher_bootstrap.admin_token
  sensitive = true
}

output "admin_password" {
  value     = module.rancher_bootstrap.admin_password
  sensitive = true
}

output "additional_node_states" {
  value     = module.cluster.additional_node_states
  sensitive = true
}

output "rancher_bootstrap_state" {
  value     = module.rancher_bootstrap.rancher_bootstrap_state
  sensitive = true
}
