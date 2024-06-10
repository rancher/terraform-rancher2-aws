locals {
  key_name       = var.key_name
  key            = var.key
  identifier     = var.identifier
  zone           = var.zone
  rke2_version   = var.rke2_version
  os             = var.os
  file_path      = var.file_path
  install_method = var.install_method
}

module "cluster" {
  source             = "./modules/cluster"
  key_name           = local.key_name
  key                = local.key
  identifier         = local.identifier
  zone               = local.zone
  rke2_version       = local.rke2_version
  rpm_channel        = "stable"
  os                 = local.os
  file_path          = local.file_path
  install_method     = local.install_method
  cni                = "canal"
  ip_family          = "ipv4"
  ingress_controller = "nginx"
  server_count       = 3
  agent_count        = 3
}
