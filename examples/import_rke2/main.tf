# provider "aws" {
#   default_tags {
#     tags = {
#       Id    = local.identifier
#       Owner = local.owner
#     }
#   }
# }

# provider "acme" {
#   server_url = "https://acme-v02.api.letsencrypt.org/directory"
# }

# provider "github" {}
# provider "kubernetes" {} # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)
# provider "helm" {}       # make sure you set the env variable KUBE_CONFIG_PATH to local_file_path (file_path variable)

# provider "rancher2" {
#   alias     = "authenticate"
#   bootstrap = true
#   api_url   = "https://${local.domain}.${local.zone}"
#   timeout   = "300s"
# }

# resource "rancher2_bootstrap" "authenticate" {
#   provider         = rancher2.authenticate
#   initial_password = module.rancher.admin_password
#   password         = module.rancher.admin_password
#   token_update     = true
#   token_ttl        = 7200 # 2 hours
# }

# provider "rancher2" {
#   alias     = "default"
#   api_url   = "https://${local.domain}.${local.zone}"
#   token_key = rancher2_bootstrap.authenticate.token
#   timeout   = "300s"
# }

# locals {
#   identifier              = var.identifier
#   example                 = "basic"
#   project_name            = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
#   username                = local.project_name
#   domain                  = local.project_name
#   zone                    = var.zone
#   key_name                = var.key_name
#   key                     = var.key
#   owner                   = var.owner
#   rke2_version            = var.rke2_version
#   local_file_path         = var.file_path
#   runner_ip               = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
#   rancher_version         = var.rancher_version
#   rancher_helm_repository = "https://releases.rancher.com/server-charts/stable"
#   cert_manager_version    = "v1.13.1"
#   os                      = "sle-micro-60"
# }

# data "http" "myip" {
#   url = "https://ipinfo.io/ip"
# }

# module "imported_rke2" {
#   source = "./modules/cluster"
# }
# module "rancher" {
#   source = "./modules/rancher"
# }

# # test catalog entry
# resource "rancher2_catalog" "foo" {
#   depends_on = [
#     module.rancher,
#   ]
#   provider = rancher2.default
#   name     = "test"
#   url      = "http://foo.com:8080"
# }
