locals {
  project_name    = var.project_name
  key_name        = var.key_name
  key             = var.key
  username        = var.username
  vpc_cidr        = var.vpc_cidr
  zone            = var.zone
  rke2_version    = var.rke2_version
  os              = var.os
  local_file_path = var.local_file_path
  workfolder      = var.workfolder
  install_method  = var.install_method
  cni             = var.cni
  cluster_size    = var.cluster_size
  admin_ip        = var.admin_ip
}

module "cluster" {
  source          = "./modules/cluster"
  project_name    = local.project_name
  key_name        = local.key_name
  key             = local.key
  username        = local.username
  vpc_cidr        = local.vpc_cidr
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
