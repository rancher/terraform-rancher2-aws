provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
}

provider "acme" {
  server_url = "${local.acme_server_url}/directory"
}

provider "github" {}
provider "kubernetes" {} # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)
provider "helm" {}       # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)

provider "rancher2" {
  alias     = "authenticate"
  bootstrap = true
  api_url   = "https://${local.domain}.${local.zone}"
  timeout   = "300s"
}

terraform {
  backend "s3" {
    # This needs to be set in the backend configs on the command line or somewhere that your identifier can be set.
    # terraform init -reconfigure -backend-config="bucket=<identifier>"
    # https://developer.hashicorp.com/terraform/language/backend/s3
    # https://developer.hashicorp.com/terraform/language/backend#partial-configuration
    key = "tfstate"
  }
}

resource "rancher2_bootstrap" "authenticate" {
  depends_on = [
    module.rancher,
  ]
  provider         = rancher2.authenticate
  initial_password = module.rancher.admin_password
  password         = module.rancher.admin_password
  token_update     = true
  token_ttl        = 7200 # 2 hours
}

provider "rancher2" {
  alias     = "default"
  api_url   = "https://${local.domain}.${local.zone}"
  token_key = rancher2_bootstrap.authenticate.token
  timeout   = "300s"
}

locals {
  identifier           = var.identifier
  example              = "basic"
  project_name         = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username             = local.project_name
  domain               = local.project_name
  zone                 = var.zone
  key_name             = var.key_name
  key                  = var.key
  acme_server_url      = "https://acme-v02.api.letsencrypt.org"
  owner                = var.owner
  rke2_version         = var.rke2_version
  rancher_helm_repo    = "https://releases.rancher.com/server-charts"
  rancher_helm_channel = "stable"
  helm_chart_strategy  = "provide"
  # These options use the Let's Encrypt cert that the module generates for you when you deploy the VPC and Domain.
  # WARNING! "hostname" must be an fqdn
  helm_chart_values = {
    "hostname"               = "${local.domain}.${local.zone}"
    "replicas"               = "2"
    "bootstrapPassword"      = "admin"
    "ingress.enabled"        = "true"
    "ingress.tls.source"     = "secret"
    "ingress.tls.secretName" = "tls-rancher-ingress"
    "privateCA"              = "true"
    "agentTLSMode"           = "system-store"
  }
  local_file_path      = var.file_path
  runner_ip            = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
  rancher_version      = var.rancher_version
  cert_manager_version = "1.18.1" #"1.16.3"
  os                   = "sle-micro-61"
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

module "rancher" {
  source = "../../"
  # project
  identifier   = local.identifier
  owner        = local.owner
  project_name = local.project_name
  domain       = local.domain
  zone         = local.zone
  # access
  key_name = local.key_name
  key      = local.key
  username = local.username
  admin_ip = local.runner_ip
  # rke2
  rke2_version    = local.rke2_version
  local_file_path = local.local_file_path
  install_method  = "rpm" # rpm only for now, need to figure out local helm chart installs otherwise
  cni             = "canal"
  node_configuration = {
    "rancherA" = {
      type            = "all-in-one"
      size            = "xxl"
      os              = local.os
      indirect_access = true
      initial         = true
    }
    "rancherB" = {
      type            = "all-in-one"
      size            = "xxl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
    "rancherC" = {
      type            = "all-in-one"
      size            = "xxl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
  }
  # rancher
  cert_manager_version            = local.cert_manager_version
  configure_cert_manager          = false # use the cert generated at the project level
  rancher_version                 = local.rancher_version
  rancher_helm_repo               = local.rancher_helm_repo
  rancher_helm_channel            = local.rancher_helm_channel
  rancher_helm_chart_use_strategy = local.helm_chart_strategy
  rancher_helm_chart_values       = local.helm_chart_values
}

data "rancher2_cluster" "local" {
  depends_on = [
    module.rancher,
    rancher2_bootstrap.authenticate,
  ]
  provider = rancher2.default
  name     = "local"
}
