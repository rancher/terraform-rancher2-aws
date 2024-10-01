locals {
  # project
  identifier   = var.identifier
  owner        = var.owner
  project_name = var.project_name
  domain       = var.domain
  zone         = var.zone
  fqdn         = join(".", [local.domain, local.zone])
  # access
  key_name = var.key_name
  key      = var.key
  username = var.username
  admin_ip = var.admin_ip
  # rke2
  rke2_version       = var.rke2_version
  local_file_path    = var.local_file_path
  install_method     = var.install_method
  cni                = var.cni
  node_configuration = var.node_configuration
  # rancher
  cert_manager_version    = var.cert_manager_version
  rancher_version         = var.rancher_version
  rancher_helm_repository = var.rancher_helm_repository
  ip_family               = "ipv4"
  ingress_controller      = "nginx"
}

module "cluster" {
  source             = "./modules/cluster"
  identifier         = local.identifier
  owner              = local.owner
  project_name       = local.project_name
  domain             = local.domain
  zone               = local.zone
  key_name           = local.key_name
  key                = local.key
  username           = local.username
  runner_ip          = local.admin_ip
  rke2_version       = local.rke2_version
  file_path          = local.local_file_path
  install_method     = local.install_method
  cni                = local.cni
  node_configuration = local.node_configuration
  ip_family          = local.ip_family
  ingress_controller = local.ingress_controller
}

module "rancher_bootstrap" {
  depends_on              = [module.cluster]
  source                  = "./modules/rancher_bootstrap"
  project_domain          = local.fqdn
  cert_manager_version    = local.cert_manager_version
  rancher_version         = local.rancher_version
  rancher_helm_repository = local.rancher_helm_repository
  project_cert_name       = module.cluster.cert.name
  project_cert_key_id     = module.cluster.cert.key_id
  path                    = local.local_file_path
}
