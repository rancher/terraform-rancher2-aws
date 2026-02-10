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
  example      = "downstream"
  project_name = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"
  username     = local.project_name
  domain       = local.project_name
  zone         = var.zone
  key_name     = var.key_name
  key          = var.key
  # "https://acme-staging-v02.api.letsencrypt.org/directory" or "https://acme-v02.api.letsencrypt.org/directory"
  acme_server_url      = var.acme_server_url
  owner                = var.owner
  rke2_version         = var.rke2_version
  local_file_path      = var.file_path
  runner_ip            = (var.runner_ip != "" ? var.runner_ip : chomp(data.http.myip.response_body)) # "runner" is the server running Terraform
  rancher_version      = var.rancher_version
  cert_manager_version = "1.18.1"
  os                   = "sle-micro-61"
  lbsg                 = sort(module.rancher.load_balancer_security_groups)
  load_balancer_security_group_id = [
    for i in range(length(local.lbsg)) :
    local.lbsg[i] if local.lbsg[i] != module.rancher.security_group.id
    # load balancers only have 2 security groups, the project and its own
    # this eliminates the project security group to just return the load balancer's security group
  ][0]
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  aws_session_token     = var.aws_session_token
  aws_region            = var.aws_region
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
  install_method  = "rpm"
  cni             = "canal"
  node_configuration = {
    "rancher" = {
      type            = "all-in-one"
      size            = "xxl"
      os              = local.os
      indirect_access = true
      initial         = true
    }
  }
  # rancher
  cert_manager_version = local.cert_manager_version
  cert_use_strategy    = "module"
  rancher_version      = local.rancher_version
  acme_server_url      = local.acme_server_url
}

module "rke2_image" {
  source              = "rancher/server/aws"
  version             = "v1.4.0"
  server_use_strategy = "skip"
  image_use_strategy  = "find"
  image_type          = local.os
}

module "downstream_security_group" {
  depends_on = [
    module.rancher,
  ]
  source                          = "./modules/downstream_securitygroups"
  name                            = "tf-multipool-sgroup"
  vpc_id                          = module.rancher.vpc.id
  load_balancer_security_group_id = local.load_balancer_security_group_id
  rancher_security_group_id       = module.rancher.security_group.id
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

# you can add this one multiple times, or use a loop to deploy multiple clusters
module "downstream" {
  depends_on = [
    module.rancher,
    module.rke2_image,
    module.downstream_security_group,
    rancher2_bootstrap.authenticate,
    data.rancher2_cluster.local,
  ]
  source = "./modules/downstream"
  providers = {
    rancher2 = rancher2.default
  }
  # general
  name       = "tf-downstream" # this must be unique per cluster
  identifier = local.identifier
  owner      = local.owner

  # aws access
  aws_access_key_id     = local.aws_access_key_id
  aws_secret_access_key = local.aws_secret_access_key
  aws_session_token     = trimspace(chomp(local.aws_session_token))
  aws_region            = local.aws_region
  aws_region_letter = replace(
    module.rancher.subnets[keys(module.rancher.subnets)[0]].availability_zone,
    local.aws_region,
    ""
  )
  downstream_security_group_name = module.downstream_security_group.name
  downstream_security_group_id   = module.downstream_security_group.id

  # aws project info
  vpc_id                          = module.rancher.vpc.id
  load_balancer_security_group_id = local.load_balancer_security_group_id
  subnet_id                       = module.rancher.subnets[keys(module.rancher.subnets)[0]].id

  # node info
  node_info = {
    all-in-one = { # this key can't have underscores
      quantity           = 1
      aws_instance_type  = "m5.large"
      aws_ami_id         = module.rke2_image.image.id
      ami_ssh_user       = module.rke2_image.image.user
      ami_admin_group    = module.rke2_image.image.admin_group
      control_plane_role = true
      etcd_role          = true
      worker_role        = true
    }
  }
  direct_node_access = {
    runner_ip       = local.runner_ip
    ssh_access_key  = local.key
    ssh_access_user = local.project_name
  }
  # rke2 info
  rke2_version = local.rke2_version
}
