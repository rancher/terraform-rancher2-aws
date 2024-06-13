provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
}

locals {
  project_name    = "tf-${local.identifier}"
  username        = lower(local.project_name)
  key_name        = var.key_name
  key             = var.key
  identifier      = var.identifier
  zone            = var.zone
  rke2_version    = var.rke2_version
  local_file_path = var.file_path
  owner           = var.owner
  runner_ip       = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

module "this" {
  source          = "../../"
  project_name    = local.project_name
  key_name        = local.key_name
  key             = local.key
  username        = local.username
  vpc_cidr        = "10.0.0.0/16"
  zone            = local.zone
  rke2_version    = local.rke2_version
  os              = "sle-micro-55"
  local_file_path = local.local_file_path
  workfolder      = "/home/${local.username}"
  install_method  = "tar"
  cni             = "canal"
  cluster_size    = 3
  admin_ip        = local.runner_ip
}

resource "local_sensitive_file" "kubeconfig" {
  content  = module.this.kubeconfig
  filename = "${path.root}/kubeconfig"
}

