output "kubeconfig" {
  value       = module.this.kubeconfig
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}
output "address" {
  value = module.this.address
}
output "admin_token" {
  value     = module.this.admin_token
  sensitive = true
}
output "admin_password" {
  value     = module.this.admin_password
  sensitive = true
}
output "additional_node_states" {
  value     = module.this.additional_node_states
  sensitive = true
}

output "rancher_bootstrap_state" {
  value     = module.this.rancher_bootstrap_state
  sensitive = true
}
