provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
}

provider "acme" {
  server_url = local.acme_server_url
}

provider "github" {}
provider "kubernetes" {} # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)
provider "helm" {}       # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)


locals {
  identifier   = var.identifier
  example      = "prod"
  project_name = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username     = local.project_name
  domain       = local.project_name
  email        = var.email
  zone         = var.zone
  key_name     = var.key_name
  key          = var.key
  # "https://acme-staging-v02.api.letsencrypt.org/directory" # "https://acme-v02.api.letsencrypt.org/directory"
  acme_server_url      = var.acme_server_url
  owner                = var.owner
  rke2_version         = var.rke2_version
  local_file_path      = var.file_path
  runner_ip            = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
  rancher_version      = var.rancher_version
  cert_manager_version = "1.18.3"
  os                   = "sle-micro-61"
  helm_chart_values = {
    "hostname"                                            = "${local.domain}.${local.zone}"
    "replicas"                                            = "3"
    "bootstrapPassword"                                   = random_password.admin_password.result
    "ingress.enabled"                                     = "true"
    "ingress.tls.source"                                  = "letsEncrypt"
    "tls"                                                 = "ingress"
    "letsEncrypt.ingress.class"                           = "nginx"
    "letsEncrypt.environment"                             = "staging" # "production"
    "letsEncrypt.email"                                   = local.email
    "certmanager.version"                                 = local.cert_manager_version
    "agentTLSMode"                                        = "strict"
    "privateCA"                                           = "true"
    "additionalTrustedCAs"                                = "true"
    "ingress.extraAnnotations.cert-manager\\.io\\/issuer" = "rancher" # hard coded
  }
  cert_manager_config = {
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
    aws_session_token     = var.aws_session_token
    aws_region            = var.aws_region
    acme_email            = local.email
    acme_server_url       = local.acme_server_url
  }
}

resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%-_=+"
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
  install_method  = "tar" # tar install, but not air-gapped
  cni             = "canal"
  node_configuration = {
    "initial" = {
      type            = "database"
      size            = "xl"
      os              = local.os
      indirect_access = false
      initial         = true # this will set the first server as the initial node
    }
    "db2" = {
      type            = "database"
      size            = "xl"
      os              = local.os
      indirect_access = false
      initial         = false
    }
    "db3" = {
      type            = "database"
      size            = "xl"
      os              = local.os
      indirect_access = false
      initial         = false
    }
    "api1" = {
      type            = "api"
      size            = "xl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
    "api2" = {
      type            = "api"
      size            = "xl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
    "api3" = {
      type            = "api"
      size            = "xl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
    "wrk1" = {
      type            = "worker"
      size            = "xxl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
    "wrk2" = {
      type            = "worker"
      size            = "xxl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
    "wrk3" = {
      type            = "worker"
      size            = "xxl"
      os              = local.os
      indirect_access = true
      initial         = false
    }
  }
  # rancher
  cert_manager_version       = local.cert_manager_version
  cert_use_strategy          = "rancher"
  cert_manager_configuration = local.cert_manager_config
  rancher_version            = local.rancher_version
  rancher_helm_chart_values  = local.helm_chart_values
  acme_server_url            = local.acme_server_url
}

provider "rancher2" {
  alias     = "authenticate"
  bootstrap = true
  api_url   = module.rancher.address
  ca_certs  = module.rancher.tls_certificate_chain
  timeout   = "300s"
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
  api_url   = module.rancher.address
  token_key = rancher2_bootstrap.authenticate.token
  ca_certs  = module.rancher.tls_certificate_chain
  timeout   = "300s"
}

data "rancher2_cluster" "local" {
  depends_on = [
    module.rancher,
    rancher2_bootstrap.authenticate,
  ]
  provider = rancher2.default
  name     = "local"
}
