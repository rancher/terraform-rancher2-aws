output "kubeconfig" {
  value       = module.this.kubeconfig
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}
output "join_url" {
  value       = module.this.join_url
  description = <<-EOT
    The URL to join this cluster.
  EOT
}
output "join_token" {
  value       = module.this.join_token
  description = <<-EOT
    The token for a server to join this cluster.
  EOT
  sensitive   = true
}
