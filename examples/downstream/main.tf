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
  # since domains can't be tagged all domains need to have the identifier in them for cleanup
  domain       = lower("${local.project_name}-${local.identifier}")
  zone         = var.zone
  rancher_fqdn = "${local.domain}.${local.zone}"
  key_name     = var.key_name
  key          = var.key
  # "https://acme-staging-v02.api.letsencrypt.org/directory" or "https://acme-v02.api.letsencrypt.org/directory"
  acme_server_url       = var.acme_server_url
  owner                 = var.owner
  rke2_version          = var.rke2_version
  local_file_path       = var.file_path
  data_dir              = (var.data_dir == "" ? path.root : var.data_dir)
  runner_ip             = (var.runner_ip != "" ? var.runner_ip : chomp(data.http.myip.response_body)) # "runner" is the server running Terraform
  rancher_version       = var.rancher_version
  rancher_instance_size = "xl"
  os                    = "sle-micro-61"
  cert_manager_version  = "1.20.2"
  downsteam_node_type   = "m7i.large"
  lbsg                  = sort(module.rancher.load_balancer_security_groups)
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
  node_profiles = {
    etcd = {
      aws_instance_type  = local.downsteam_node_type
      aws_ami_id         = module.rke2_image.image.id
      ami_ssh_user       = module.rke2_image.image.user
      ami_admin_group    = module.rke2_image.image.admin_group
      etcd_role          = true
      control_plane_role = false
      worker_role        = false
    }
    api = {
      aws_instance_type  = local.downsteam_node_type
      aws_ami_id         = module.rke2_image.image.id
      ami_ssh_user       = module.rke2_image.image.user
      ami_admin_group    = module.rke2_image.image.admin_group
      control_plane_role = true
      etcd_role          = false
      worker_role        = false
    }
    worker = {
      aws_instance_type  = local.downsteam_node_type
      aws_ami_id         = module.rke2_image.image.id
      ami_ssh_user       = module.rke2_image.image.user
      ami_admin_group    = module.rke2_image.image.admin_group
      worker_role        = true
      control_plane_role = false
      etcd_role          = false
    }
    control-plane = {
      aws_instance_type  = local.downsteam_node_type
      aws_ami_id         = module.rke2_image.image.id
      ami_ssh_user       = module.rke2_image.image.user
      ami_admin_group    = module.rke2_image.image.admin_group
      control_plane_role = true
      etcd_role          = true
      worker_role        = false
    }
    all = {
      aws_instance_type  = local.downsteam_node_type
      aws_ami_id         = module.rke2_image.image.id
      ami_ssh_user       = module.rke2_image.image.user
      ami_admin_group    = module.rke2_image.image.admin_group
      control_plane_role = true
      etcd_role          = true
      worker_role        = true
    }
  }
  configs = {
    all-in-one-dev-node-config = {
      all = merge({ quantity = 1 }, local.node_profiles.all)
    }
    all-in-one-ha-node-config = {
      all = merge({ quantity = 3 }, local.node_profiles.all)
    }
    split-role-node-config = {
      control-plane = merge({ quantity = 3 }, local.node_profiles.control-plane)
      worker        = merge({ quantity = 3 }, local.node_profiles.worker)
    }
    prod-node-config = {
      etcd          = merge({ quantity = 3 }, local.node_profiles.etcd)
      control-plane = merge({ quantity = 3 }, local.node_profiles.api)
      worker        = merge({ quantity = 3 }, local.node_profiles.worker)
    }
  }

  helm_chart_values = {
    "hostname"                                            = local.rancher_fqdn
    "replicas"                                            = "1"
    "ingress.enabled"                                     = "true"
    "ingress.tls.source"                                  = "letsEncrypt"
    "tls"                                                 = "ingress"
    "agentTLSMode"                                        = "strict"
    "privateCA"                                           = "true"
    "additionalTrustedCAs"                                = "true"
    "ingress.extraAnnotations.cert-manager\\.io\\/issuer" = "rancher"
  }
  # example data_dir = "../../abc123"
  # default data_dir = "."
  node_config = var.downstream_node_config
  # local.data_dir is the relative path from path.root to TF_DATA_DIR
  downstream_deploy_path = "${local.data_dir}/downstream_deploy_${local.identifier}"
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
  install_method  = "tar" # this installs RKE using the tar method, but it isn't an air-gapped install, Rancher install still uses public helm chart
  cni             = "canal"
  node_configuration = {
    "rancher" = {
      type            = "all-in-one"
      size            = local.rancher_instance_size
      os              = local.os
      indirect_access = true
      initial         = true
    }
  }
  # rancher
  cert_manager_version            = local.cert_manager_version
  cert_use_strategy               = "module"
  rancher_version                 = local.rancher_version
  rancher_helm_chart_use_strategy = "merge"
  rancher_helm_repo               = "https://releases.rancher.com/server-charts"
  rancher_helm_chart_values       = local.helm_chart_values
  acme_server_url                 = local.acme_server_url
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

module "deploy_downstream" {
  depends_on = [
    module.rancher,
    module.rke2_image,
    module.downstream_security_group,
  ]
  source = "./modules/deploy"

  deploy_path = local.downstream_deploy_path
  data_path   = local.downstream_deploy_path

  deploy_trigger = md5(join("-", [
    jsonencode(local.configs[local.node_config]),
    module.rancher.address,
    module.rancher.vpc.id
  ]))

  environment_variables = {
    # don't place secrets here, those env variables will be inherited.
  }

  inputs = <<-EOT
    aws_region                      = "${base64encode(local.aws_region)}"
    identifier                      = "${base64encode(local.identifier)}"
    owner                           = "${base64encode(local.owner)}"
    rancher_address                 = "${base64encode(module.rancher.address)}"
    rancher_admin_password          = "${base64encode(module.rancher.admin_password)}"
    rancher_admin_token             = "${base64encode(module.rancher.admin_token)}"
    tls_certificate_chain           = "${base64encode(module.rancher.tls_certificate_chain)}"
    node_config_name                = "${base64encode("tf-${local.node_config}")}"
    aws_access_key_id               = "${base64encode(local.aws_access_key_id)}"
    aws_secret_access_key           = "${base64encode(local.aws_secret_access_key)}"
    aws_session_token               = "${base64encode(trimspace(chomp(local.aws_session_token)))}"
    aws_region_letter               = "${base64encode(replace(module.rancher.subnets[keys(module.rancher.subnets)[0]].availability_zone, local.aws_region, ""))}"
    downstream_security_group_name  = "${base64encode(module.downstream_security_group.name)}"
    vpc_id                          = "${base64encode(module.rancher.vpc.id)}"
    load_balancer_security_group_id = "${base64encode(local.load_balancer_security_group_id)}"
    subnet_id                       = "${base64encode(module.rancher.subnets[keys(module.rancher.subnets)[0]].id)}"
    node_info                       = "${base64encode(jsonencode(local.configs[local.node_config]))}"
    runner_ip                       = "${base64encode(local.runner_ip)}"
    ssh_access_key                  = "${base64encode(local.key)}"
    ssh_access_user                 = "${base64encode(local.project_name)}"
    rke2_version                    = "${base64encode(local.rke2_version)}"
  EOT
  template_files = {
    "./variables.tf"                               = "${path.module}/downstream/variables.tf"
    "./versions.tf"                                = "${path.module}/downstream/versions.tf"
    "./outputs.tf"                                 = "${path.module}/downstream/outputs.tf"
    "./modules/downstream/main.tf"                 = "${path.module}/modules/downstream/main.tf"
    "./modules/downstream/variables.tf"            = "${path.module}/modules/downstream/variables.tf"
    "./modules/downstream/versions.tf"             = "${path.module}/modules/downstream/versions.tf"
    "./modules/downstream/outputs.tf"              = "${path.module}/modules/downstream/outputs.tf"
    "./modules/downstream/login.sh"                = "${path.module}/modules/downstream/login.sh"
    "./modules/downstream/addKeyToAmazonConfig.sh" = "${path.module}/modules/downstream/addKeyToAmazonConfig.sh"
  }
  generated_files = {
    "main.tf" = file("${path.module}/downstream/main.tf.tftpl")
  }
}
