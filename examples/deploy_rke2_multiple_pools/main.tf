provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
  region = local.aws_region
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

resource "rancher2_bootstrap" "authenticate" {
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
  rancher_version         = var.rancher_version
  rancher_helm_repository = "https://releases.rancher.com/server-charts/stable"
  cert_manager_version    = "1.16.3" #"1.13.1"
  os                      = "sle-micro-60"
  acme_server_url         = "https://acme-v02.api.letsencrypt.org"
  aws_access_key_id       = var.aws_access_key_id
  aws_secret_access_key   = var.aws_secret_access_key
  aws_region              = var.aws_region
  aws_session_token       = var.aws_session_token
  email                   = (var.email != "" ? var.email : "${local.identifier}@${local.zone}")
  private_ip              = replace(module.rancher.private_endpoint, "http://", "")
  hostname_prefix         = local.project_name
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

module "rancher" {
  source = "../../"
  # project
  identifier                   = local.identifier
  owner                        = local.owner
  project_name                 = local.project_name
  domain                       = local.domain
  zone                         = local.zone
  skip_project_cert_generation = true
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
    "rancher" = {
      type            = "all-in-one"
      size            = "large"
      os              = local.os
      indirect_access = true
      initial         = true
    }
  }
  # rancher
  rancher_version         = local.rancher_version
  rancher_helm_repository = local.rancher_helm_repository
  cert_manager_version    = local.cert_manager_version
  configure_cert_manager  = true
  cert_manager_configuration = {
    aws_access_key_id     = local.aws_access_key_id
    aws_secret_access_key = local.aws_secret_access_key
    aws_region            = local.aws_region
    aws_session_token     = local.aws_session_token
    acme_email            = local.email
    acme_server_url       = local.acme_server_url
  }
}

module "rke2_image" {
  source              = "rancher/server/aws"
  version             = "v1.3.1"
  server_use_strategy = "skip"
  image_use_strategy  = "find"
  image_type          = local.os
}

# this adds the private (10.) IP to the domain
# the private IP communicates to the agents where to find Rancher
resource "aws_route53_record" "modified" {
  depends_on = [
    module.rancher,
  ]
  zone_id         = module.rancher.domain_object.zone_id
  name            = module.rancher.domain_object.name
  type            = module.rancher.domain_object.type
  ttl             = 30
  records         = concat([local.private_ip], tolist(module.rancher.domain_object.records))
  allow_overwrite = true
}

resource "rancher2_machine_config_v2" "core" {
  depends_on = [
    rancher2_bootstrap.authenticate,
    module.rancher,
    aws_route53_record.modified,
  ]
  provider      = rancher2.default
  generate_name = "core-rke2-template"
  amazonec2_config {
    ami            = module.rke2_image.image.id
    region         = local.aws_region
    security_group = [module.rancher.security_group.name]
    subnet_id      = module.rancher.subnets[keys(module.rancher.subnets)[0]].id
    vpc_id         = module.rancher.vpc.id
    zone = replace( # it is looking for just the last letter of the availability zone, eg. for us-west-2a it just wants 'a'
      module.rancher.subnets[keys(module.rancher.subnets)[0]].availability_zone,
      local.aws_region, # so we take the full string ^ eg. us-west-2a
      ""                # and remove the region eg. us-west-2 to get just 'a'
    )
    session_token = trimspace(chomp(local.aws_session_token))
    instance_type = "m5.large"
    ssh_user      = "ec2-user"
    userdata      = <<-EOT
      #cloud-config
      bootcmd:
        - echo ${local.private_ip} ${local.domain}.${local.zone} >> /etc/hosts
    EOT
    tags          = join(",", ["Id", local.identifier, "Owner", local.owner])
  }
}
resource "rancher2_machine_config_v2" "worker" {
  depends_on = [
    rancher2_bootstrap.authenticate,
    module.rancher,
    aws_route53_record.modified,
  ]
  provider      = rancher2.default
  generate_name = "worker-rke2-template"
  amazonec2_config {
    ami            = module.rke2_image.image.id
    region         = local.aws_region
    security_group = [module.rancher.security_group.name]
    subnet_id      = module.rancher.subnets[keys(module.rancher.subnets)[0]].id
    vpc_id         = module.rancher.vpc.id
    zone = replace( # it is looking for just the last letter of the availability zone, eg. for us-west-2a it just wants 'a'
      module.rancher.subnets[keys(module.rancher.subnets)[0]].availability_zone,
      local.aws_region,
      ""
    )
    session_token = trimspace(chomp(local.aws_session_token))
    instance_type = "m5.large"
    ssh_user      = "ec2-user"
    userdata      = <<-EOT
      #cloud-config
      bootcmd:
        - echo ${local.private_ip} ${local.domain}.${local.zone} >> /etc/hosts
    EOT
    tags          = join(",", ["Id", local.identifier, "Owner", local.owner])
  }
}

resource "terraform_data" "patch_machine_configs" {
  depends_on = [
    rancher2_bootstrap.authenticate,
    module.rancher,
    aws_route53_record.modified,
    rancher2_machine_config_v2.core,
    rancher2_machine_config_v2.worker,
  ]
  triggers_replace = {
    core_config   = rancher2_machine_config_v2.core.id
    worker_config = rancher2_machine_config_v2.worker.id
  }
  provisioner "local-exec" {
    command = <<-EOT
      ${path.module}/addKeyToMachineTemplate.sh "${local.aws_access_key_id}" "${local.aws_secret_access_key}"
    EOT
  }
}

resource "rancher2_cluster_v2" "rke2_cluster" {
  depends_on = [
    module.rancher,
    rancher2_bootstrap.authenticate,
    module.rancher,
    aws_route53_record.modified,
    rancher2_machine_config_v2.core,
    rancher2_machine_config_v2.worker,
    terraform_data.patch_machine_configs,
  ]
  provider              = rancher2.default
  name                  = "${local.project_name}-s1-cluster"
  kubernetes_version    = local.rke2_version
  enable_network_policy = true
  rke_config {
    machine_pools {
      name               = "${local.hostname_prefix}cp"
      control_plane_role = true
      etcd_role          = true
      worker_role        = true
      quantity           = 1
      machine_config {
        kind = rancher2_machine_config_v2.core.kind
        name = rancher2_machine_config_v2.core.name
      }
    }
    machine_pools {
      name               = "${local.hostname_prefix}wk"
      control_plane_role = true
      etcd_role          = true
      worker_role        = true
      quantity           = 1
      machine_config {
        kind = rancher2_machine_config_v2.worker.kind
        name = rancher2_machine_config_v2.worker.name
      }
    }
    rotate_certificates {
      generation = 1
    }
  }
  timeouts {
    create = "120m" # 2 hours
  }
}

resource "rancher2_cluster_sync" "sync" {
  depends_on = [
    module.rancher,
    rancher2_bootstrap.authenticate,
    module.rancher,
    aws_route53_record.modified,
    rancher2_machine_config_v2.core,
    rancher2_machine_config_v2.worker,
    terraform_data.patch_machine_configs,
    rancher2_cluster_v2.rke2_cluster,
  ]
  provider   = rancher2.default
  cluster_id = rancher2_cluster_v2.rke2_cluster.cluster_v1_id
}
