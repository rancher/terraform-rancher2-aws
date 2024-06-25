output "kubeconfig" {
  value       = module.initial.kubeconfig
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}
output "join_url" {
  value       = module.initial.join_url
  description = <<-EOT
    The URL to join this cluster.
  EOT
}
output "join_token" {
  value       = module.initial.join_token
  description = <<-EOT
    The token for a server to join this cluster.
  EOT
  sensitive   = true
}

