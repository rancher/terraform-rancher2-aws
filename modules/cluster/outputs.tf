output "kubeconfig" {
  value       = local.ino.output.kubeconfig
  description = "Kubernetes config file contents for the cluster."
  sensitive   = true
}
output "api" {
  value       = yamldecode(local.ino.output.kubeconfig).clusters[0].cluster.server
  description = "Address to use to connect to the cluster's API service."
  sensitive   = true
}
output "cert" {
  value       = local.ino.output.project_domain_tls_certificate
  description = "Information about the certificate that was generated with the domain"
  sensitive   = true
}
output "vpc" {
  value = local.ino.output.project_vpc
}
output "subnets" {
  value = local.ino.output.project_subnets
}
output "join_url" {
  value = local.ino.output.join_url
}
output "initial_node_private_ip" {
  value = replace(replace(local.ino.output.join_url, ":9345", ""), "https://", "")
}
output "project_domain_object" {
  value = local.ino.output.project_domain_object
}
output "project_security_group" {
  value = local.ino.output.project_security_group
}
output "load_balancer_security_groups" {
  value = local.ino.output.project_load_balancer.security_groups
}
# commented for performance, leaving to show how you can export the state if necessary
# output "additional_node_states" {
#   value       = data.terraform_remote_state.additional_node_states
#   description = "The states for the orchestrated modules which produce nodes."
#   sensitive   = true
# }
