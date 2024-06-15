locals {
  project_name            = var.project_name
  project_domain          = var.project_domain
  zone                    = var.zone
  key_name                = var.key_name
  key                     = var.key
  username                = var.username
  vpc_cidr                = var.vpc_cidr
  rke2_version            = var.rke2_version
  os                      = var.os
  local_file_path         = var.local_file_path
  workfolder              = var.workfolder
  install_method          = var.install_method
  cni                     = var.cni
  cluster_size            = var.cluster_size
  admin_ip                = var.admin_ip
  rancher_version         = var.rancher_version
  rancher_helm_repository = var.rancher_helm_repository
  cert_manager_version    = var.cert_manager_version
}

module "cluster" {
  source          = "./modules/cluster"
  project_name    = local.project_name
  key_name        = local.key_name
  key             = local.key
  username        = local.username
  vpc_cidr        = local.vpc_cidr
  domain          = local.project_domain
  zone            = local.zone
  rke2_version    = local.rke2_version
  os              = local.os
  local_file_path = local.local_file_path
  workfolder      = local.workfolder
  install_method  = local.install_method
  cni             = local.cni
  cluster_size    = local.cluster_size
  admin_ip        = local.admin_ip
}

module "rancher_bootstrap" {
  depends_on              = [module.cluster]
  source                  = "./modules/rancher_bootstrap"
  project_domain          = local.project_domain
  rancher_version         = local.rancher_version
  rancher_helm_repository = local.rancher_helm_repository
  cert_manager_version    = local.cert_manager_version
}
