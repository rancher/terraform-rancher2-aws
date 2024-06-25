provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
}
provider "kubernetes" {
  config_path = "${local.local_file_path}/kubeconfig"
}

provider "helm" {
  kubernetes {
    config_path = "${local.local_file_path}/kubeconfig"
  }
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://${local.domain}"
  insecure  = true
  bootstrap = true
}

provider "rancher2" {
  alias     = "admin"
  api_url   = "https://${local.domain}"
  insecure  = true
  token_key = rancher2_bootstrap.admin.token
  timeout   = "300s"
}

locals {
  project_name    = "tf-${local.identifier}"
  username        = lower(local.project_name)
  domain          = lower(local.project_name)
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
  project_domain  = local.domain
  zone            = local.zone
  key_name        = local.key_name
  key             = local.key
  username        = local.username
  rke2_version    = local.rke2_version
  local_file_path = local.local_file_path
  vpc_cidr        = "10.0.0.0/16"
  os              = "sle-micro-55"
  workfolder      = "/home/${local.username}"
  install_method  = "tar"
  cni             = "canal"
  cluster_size    = 1
  admin_ip        = local.runner_ip
}
