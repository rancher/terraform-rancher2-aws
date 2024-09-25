output "kubeconfig" {
  value       = module.initial.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
output "api" {
  value       = yamldecode(module.initial.kubeconfig).clusters[0].cluster.server
  description = "Address to use to connect to the cluster's API service."
  sensitive   = true
}
output "cert" {
  value = module.initial.project_domain_tls_certificate
}
