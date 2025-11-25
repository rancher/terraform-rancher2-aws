output "kubeconfig" {
  value       = module.rancher.kubeconfig
  description = <<-EOT
    The kubeconfig for the server.
  EOT
  sensitive   = true
}
output "address" {
  value     = module.rancher.address
  sensitive = true
}
output "admin_token" {
  value     = module.rancher.admin_token
  sensitive = true
}
output "admin_password" {
  value     = module.rancher.admin_password
  sensitive = true
}
output "cluster_data" {
  value     = jsonencode(data.rancher2_cluster.local)
  sensitive = true
}
output "subnets" {
  value     = module.rancher.subnets
  sensitive = true
}
output "vpc" {
  value     = module.rancher.vpc
  sensitive = true
}
output "security_group" {
  value     = module.rancher.security_group
  sensitive = true
}
output "load_balancer_security_groups" {
  value     = module.rancher.load_balancer_security_groups
  sensitive = true
}
output "tls_certificate_chain" {
  value     = module.rancher.tls_certificate_chain
  sensitive = true
}
output "downstream_ssh_access" {
  value = [for i in range(length(module.downstream.public_ips)) :
    "ssh -i ${local.local_file_path}/id_rsa ${local.username}@${module.downstream.public_ips[i]}"
  ]
}
