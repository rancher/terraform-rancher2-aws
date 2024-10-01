output "kubeconfig" {
  value       = local.ino.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
output "api" {
  value       = yamldecode(local.ino.kubeconfig).clusters[0].cluster.server
  description = "Address to use to connect to the cluster's API service."
  sensitive   = true
}
output "cert" {
  value       = local.ino.project_domain_tls_certificate
  description = "Information about the certificate that was generated with the domain"
  sensitive   = true
}
output "additional_node_states" {
  value       = data.terraform_remote_state.additional_node_states
  description = "The states for the orchestrated modules which produce nodes."
  sensitive   = true
}
