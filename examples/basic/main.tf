provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

provider "github" {}
provider "kubernetes" {} # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)
provider "helm" {}       # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)

provider "rancher2" {
  api_url   = "https://${local.domain}.${local.zone}"
  token_key = module.this.admin_token
  timeout   = "300s"
}

locals {
  identifier              = var.identifier
  example                 = "basic"
  project_name            = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username                = local.project_name
  domain                  = local.project_name
  zone                    = var.zone
  key_name                = var.key_name
  key                     = var.key
  owner                   = var.owner
  rke2_version            = var.rke2_version
  local_file_path         = var.file_path
  runner_ip               = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
  cluster_size            = 3
  rancher_version         = var.rancher_version
  rancher_helm_repository = "https://releases.rancher.com/server-charts/stable"
  cert_manager_version    = "v1.11.0"
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

module "this" {
  source                  = "../../"
  project_name            = local.project_name
  project_domain          = local.domain
  zone                    = local.zone
  key_name                = local.key_name
  key                     = local.key
  username                = local.username
  rke2_version            = local.rke2_version
  local_file_path         = local.local_file_path
  os                      = "sle-micro-55"
  install_method          = "rpm" # rpm only for now, need to figure out local helm chart installs otherwise
  cni                     = "canal"
  api_nodes               = local.cluster_size
  database_nodes          = local.cluster_size
  worker_nodes            = local.cluster_size
  size                    = "small"
  admin_ip                = local.runner_ip
  rancher_version         = local.rancher_version
  rancher_helm_repository = local.rancher_helm_repository
  cert_manager_version    = local.cert_manager_version
  identifier              = local.identifier
  owner                   = local.owner
}

# test catalog entry
resource "rancher2_catalog" "foo" {
  depends_on = [
    module.this,
  ]
  name = "test"
  url  = "http://foo.com:8080"
}
