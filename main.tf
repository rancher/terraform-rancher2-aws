locals {
  project_name            = var.project_name
  project_domain          = var.project_domain
  zone                    = var.zone
  key_name                = var.key_name
  key                     = var.key
  username                = var.username
  rke2_version            = var.rke2_version
  os                      = var.os
  size                    = var.size
  local_file_path         = var.local_file_path
  workfolder              = var.workfolder
  install_method          = var.install_method
  cni                     = var.cni
  admin_ip                = var.admin_ip
  rancher_version         = var.rancher_version
  rancher_helm_repository = var.rancher_helm_repository
  cert_manager_version    = var.cert_manager_version
  api_nodes               = var.api_nodes
  database_nodes          = var.database_nodes
  worker_nodes            = var.worker_nodes
  ip_family               = "ipv4"
  identifier              = var.identifier
  owner                   = var.owner
  fqdn                    = join(".", [local.project_domain, local.zone])
}

module "cluster" {
  source         = "./modules/cluster"
  identifier     = local.identifier
  owner          = local.owner
  key_name       = local.key_name
  key            = local.key
  zone           = local.zone
  rke2_version   = local.rke2_version
  os             = local.os
  file_path      = local.local_file_path
  install_method = local.install_method
  cni            = local.cni
  ip_family      = local.ip_family
  api_nodes      = local.api_nodes
  database_nodes = local.database_nodes
  worker_nodes   = local.worker_nodes
  runner_ip      = local.admin_ip
  project_name   = local.project_name
  username       = local.username
  domain         = local.project_domain
  size           = local.size
}

module "rancher_bootstrap" {
  depends_on              = [module.cluster]
  source                  = "./modules/rancher_bootstrap"
  project_domain          = local.fqdn
  rancher_version         = local.rancher_version
  rancher_helm_repository = local.rancher_helm_repository
  cert_manager_version    = local.cert_manager_version
  project_cert_name       = module.cluster.cert.name
  project_cert_key_id     = module.cluster.cert.key_id
  path                    = local.local_file_path
}
