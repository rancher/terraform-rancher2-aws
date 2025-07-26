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
  value     = module.rancher_bootstrap[0].admin_token
  sensitive = true
}

output "admin_password" {
  value     = module.rancher_bootstrap[0].admin_password
  sensitive = true
}

output "vpc" {
  value = module.cluster.vpc
}
output "subnets" {
  value = module.cluster.subnets
}
output "security_group" {
  value = module.cluster.project_security_group
}
output "load_balancer_security_groups" {
  value = module.cluster.load_balancer_security_groups
}
output "private_endpoint" {
  value = replace(replace(module.cluster.join_url, ":9345", ""), "https", "http")
}
output "domain_object" {
  value = module.cluster.project_domain_object
}
output "tls_certificate_chain" {
  value = module.rancher_bootstrap[0].ca_certs
}
