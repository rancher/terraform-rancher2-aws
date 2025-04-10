locals {
  # project
  identifier   = var.identifier
  owner        = var.owner
  project_name = var.project_name
  domain       = var.domain
  zone         = var.zone
  fqdn         = join(".", [local.domain, local.zone])
  skip_cert    = var.skip_project_cert_generation
  # access
  key_name = var.key_name
  key      = var.key
  username = var.username
  admin_ip = var.admin_ip
  # rke2
  rke2_version = var.rke2_version
  local_file_path = (
    var.local_file_path != "" ? (var.local_file_path == path.root ? "${abspath(path.root)}/rke2" : abspath(var.local_file_path)) :
    "${abspath(path.root)}/rke2"
  )
  install_method     = var.install_method
  cni                = var.cni
  node_configuration = var.node_configuration
  # rancher
  cert_manager_version   = var.cert_manager_version
  rancher_version        = var.rancher_version
  ip_family              = "ipv4"
  ingress_controller     = "nginx"
  bootstrap_rancher      = var.bootstrap_rancher
  install_cert_manager   = var.install_cert_manager
  configure_cert_manager = var.configure_cert_manager
  cert_manager_config    = var.cert_manager_configuration

  # remote state files
  install_cert_manager_backend = var.install_cert_manager_backend
  rancher_bootstrap_backend    = var.rancher_bootstrap_backend
  # the cluster submodule uses the main state
}

data "aws_route53_zone" "zone" {
  name = "${local.zone}."
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
  skip_cert_creation = local.skip_cert
}

module "install_cert_manager" {
  depends_on = [
    module.cluster,
  ]
  count                      = (local.install_cert_manager ? 1 : 0)
  source                     = "./modules/install_cert_manager"
  project_domain             = local.fqdn
  zone                       = local.zone
  zone_id                    = data.aws_route53_zone.zone.zone_id
  project_cert_name          = module.cluster.cert.name
  project_cert_key_id        = module.cluster.cert.key_id
  path                       = local.local_file_path
  cert_manager_version       = local.cert_manager_version
  configure_cert_manager     = local.configure_cert_manager
  cert_manager_configuration = local.cert_manager_config
  backend_file               = local.install_cert_manager_backend
}

module "rancher_bootstrap" {
  depends_on = [
    module.cluster,
    module.install_cert_manager,
  ]
  count                      = (local.bootstrap_rancher ? 1 : 0)
  source                     = "./modules/rancher_bootstrap"
  path                       = local.local_file_path
  project_domain             = local.fqdn
  zone                       = local.zone
  zone_id                    = data.aws_route53_zone.zone.zone_id
  region                     = local.cert_manager_config.aws_region
  email                      = local.cert_manager_config.acme_email
  acme_server_url            = local.cert_manager_config.acme_server_url
  rancher_version            = local.rancher_version
  cert_manager_version       = local.cert_manager_version
  externalTLS                = (local.configure_cert_manager ? false : true)
  cert_manager_configuration = local.cert_manager_config
  backend_file               = local.rancher_bootstrap_backend
}
