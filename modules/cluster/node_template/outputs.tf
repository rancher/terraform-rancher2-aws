output "kubeconfig" {
  value     = module.node.kubeconfig
  sensitive = true
}
output "join_url" {
  value = module.node.join_url
}
output "join_token" {
  value     = module.node.join_token
  sensitive = true
}
output "cluster_cidr" {
  value = module.node.cluster_cidr
}
output "service_cidr" {
  value = module.node.service_cidr
}
output "project_subnets" {
  value = module.node.project_subnets
}
output "project_security_group" {
  value = module.node.project_security_group
}
output "project_domain_tls_certificate" {
  value     = module.node.project_domain_tls_certificate
  sensitive = true
}
output "project_vpc" {
  value = module.node.project_vpc
}
output "project_domain_object" {
  value = module.node.project_domain_object
}
output "project_load_balancer" {
  value = module.node.project_load_balancer
}

