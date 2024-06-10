locals {
  # project options
  identifier   = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  email        = "terraform-ci@suse.com"
  example      = "one"
  project_name = "tf-${substr(md5(join("-", [local.example, local.identifier])), 0, 5)}"

  # deployment options
  username = lower(substr("tf-${local.identifier}", 0, 32))
  # tflint-ignore: terraform_unused_declarations
  ip_family = var.ip_family # not currently in use, TODO: add dualstack functionality
  # tflint-ignore: terraform_unused_declarations
  ingress_controller = var.ingress_controller # not currently in use, TODO: add traefik functionality
  vpc_cidr           = "10.0.0.0/16"
  runner_ip          = chomp(data.http.myip.response_body) # "runner" is the server running Terraform
  ssh_key            = var.key
  ssh_key_name       = var.key_name
  zone               = var.zone
  image              = var.os

  # static install and config options
  rke2_version   = var.rke2_version
  rpm_channel    = var.rpm_channel
  install_method = var.install_method
  install_prep_script = (
    strcontains(local.image, "sles-15") ? file("${path.root}/suse_prep.sh") :
    (strcontains(local.image, "ubuntu") ? file("${path.root}/ubuntu_prep.sh") :
      (strcontains(local.image, "rhel") ? file("${path.root}/rhel_prep.sh") :
  "")))
  download     = (local.install_method == "tar" ? "download" : "skip")
  cni          = var.cni
  config_strat = (local.cni == "canal" ? "default" : "merge")
  cni_file     = (local.cni == "cilium" ? "${path.root}/cilium.yaml" : (local.cni == "calico" ? "${path.root}/calico.yaml" : ""))
  cni_config   = (local.cni_file != "" ? file(local.cni_file) : "")

  # WARNING! Local file path needs to be isolated, don't use the same path as your terraform files
  local_file_path = (var.file_path != "" ? (var.file_path == path.root ? "${abspath(path.root)}/rke2" : var.file_path) : "${abspath(path.root)}/rke2")
  workfolder      = (strcontains(local.image, "cis") ? "/var/tmp" : "/home/${local.username}")

  # cluster scale options
  server_count = var.server_count
  agent_count  = var.agent_count
  cluster_size = (local.server_count + local.agent_count)
  project_subnets = { for i in range(length(data.aws_availability_zones.available.names)) :
    "${data.aws_availability_zones.available.names[i]}-${local.identifier}" => {
      "cidr"              = cidrsubnet(local.vpc_cidr, (length(data.aws_availability_zones.available.names) - 1), (i))
      "availability_zone" = data.aws_availability_zones.available.names[i]
      public              = true
    }
  }
  node_ids   = [for i in range(local.cluster_size) : "${local.project_name}-${substr(md5(uuidv5("dns", tostring(i))), 0, 4)}"]
  subnet_ids = [for i in range(length(data.aws_availability_zones.available.names)) : "${data.aws_availability_zones.available.names[i]}-${local.identifier}"]
  node_subnets = { for i in range(local.cluster_size) :
    local.node_ids[i] => local.subnet_ids[i % length(local.subnet_ids)]
  }
  subnet_nodes = { for subnet in local.subnet_ids :
    subnet => [for k, v in local.node_subnets : k if v == subnet]
  }
  node_ips = { for i in range(local.cluster_size) :
    # local.server_subnets[server_ids[i]] = subnet id which is ("${data.aws_availability_zones.available.names[i]}-sn") eg. "us-west-2b-sn"
    local.node_ids[i] => cidrhost(
      local.project_subnets[local.node_subnets[local.node_ids[i]]]["cidr"],
      index(local.subnet_nodes[local.node_subnets[local.node_ids[i]]], local.node_ids[i]) + 6
    )
  }

  ## servers
  server_ids     = [for i in range(local.server_count) : local.node_ids[i]]
  server_subnets = { for id in local.server_ids : id => local.node_subnets[id] }
  server_ips     = { for id in local.server_ids : id => local.node_ips[id] }

  ## agents
  agent_ids     = [for i in range(local.agent_count) : local.node_ids[local.server_count + i]]
  agent_subnets = { for id in local.agent_ids : id => local.node_subnets[id] }
  agent_ips     = { for id in local.agent_ids : id => local.node_ips[id] }

  ## node info
  initial_server_info = {
    "name"   = local.server_ids[0]
    "ip"     = local.server_ips[local.server_ids[0]]
    "subnet" = local.server_subnets[local.server_ids[0]]
    "domain" = "${local.server_ids[0]}.${local.zone}"
  }
  additional_server_info = { for id in local.server_ids :
    id => {
      "name"   = id
      "ip"     = local.server_ips[id]
      "subnet" = local.server_subnets[id]
      "domain" = "${id}.${local.zone}"
    }
    if id != local.server_ids[0]
  }
  agent_info = { for id in local.agent_ids :
    id => {
      "name"   = id
      "ip"     = local.agent_ips[id]
      "subnet" = local.agent_subnets[id]
      "domain" = "${id}.${local.zone}"
    }
  }
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "cluster" {
  source = "./modules/cluster"

}

module "initial" {
  source                              = "rancher/rke2/aws"
  version                             = "1.0.0"
  project_use_strategy                = "create"
  project_vpc_use_strategy            = "create"
  project_vpc_name                    = "${local.project_name}-vpc"
  project_vpc_cidr                    = local.vpc_cidr
  project_subnet_use_strategy         = "create"
  project_subnets                     = local.project_subnets
  project_security_group_use_strategy = "create"
  project_security_group_name         = "${local.project_name}-sg"
  project_security_group_type         = (local.install_method == "rpm" ? "egress" : "project") # rpm install requires downloading dependencies
  project_load_balancer_use_strategy  = "create"
  project_load_balancer_name          = "${local.project_name}-lb"
  project_load_balancer_access_cidrs = {
    ping = {
      port     = "443"
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to ping service from this CIDR only
    }
  }
  project_domain_use_strategy         = "create"
  project_domain                      = "${local.project_name}.${local.zone}"
  server_use_strategy                 = "create"
  server_name                         = local.initial_server_info["name"]
  server_type                         = "small" # smallest viable control plane node (actually t3.medium)
  server_subnet_name                  = local.initial_server_info["subnet"]
  server_security_group_name          = "${local.project_name}-sg"
  server_private_ip                   = local.initial_server_info["ip"]
  server_image_use_strategy           = "find"
  server_image_type                   = local.image
  server_cloudinit_use_strategy       = "skip" # cloud-init not available for sle-micro
  server_indirect_access_use_strategy = "enable"
  server_load_balancer_target_groups  = ["${local.project_name}-lb-ping"] # this will always be <load balancer name>-<load balancer access cidrs key>
  server_direct_access_use_strategy   = "ssh"                             # configure the servers for direct ssh access
  server_access_addresses = {                                             # you must include ssh access here to enable setup
    runnerSsh = {
      port     = 22 # allow access on ssh port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
    runnerKubectl = {
      port     = 6443 # allow access on this port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
  }
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = local.workfolder
    timeout                  = 5
  }
  server_add_domain        = true
  server_domain_name       = local.initial_server_info["domain"]
  server_domain_zone       = local.zone
  server_add_eip           = false
  install_use_strategy     = local.install_method
  local_file_use_strategy  = local.download
  local_file_path          = "${local.local_file_path}/${local.initial_server_info["name"]}"
  install_rke2_version     = local.rke2_version
  install_rpm_channel      = local.rpm_channel
  install_remote_file_path = "${local.workfolder}/rke2"
  install_role             = "server"
  install_start            = true
  install_prep_script      = local.install_prep_script
  install_start_timeout    = 5
  config_use_strategy      = local.config_strat
  config_default_name      = "50-default-config.yaml"
  config_supplied_content  = local.cni_config
  config_supplied_name     = "51-cni-config.yaml"
  retrieve_kubeconfig      = true
}

module "additional" {
  for_each                            = local.additional_server_info
  depends_on                          = [module.initial]
  source                              = "../../" # this source is dev use only, see https://registry.terraform.io/modules/rancher/rke2/aws/latest
  project_use_strategy                = "skip"
  server_use_strategy                 = "create"
  server_name                         = each.value["name"]
  server_type                         = "small" # smallest viable control plane node (actually t3.medium)
  server_subnet_name                  = each.value["subnet"]
  server_security_group_name          = "${local.project_name}-sg"
  server_private_ip                   = each.value["ip"]
  server_image_use_strategy           = "find"
  server_image_type                   = local.image
  server_cloudinit_use_strategy       = "skip" # cloud-init not available for sle-micro
  server_indirect_access_use_strategy = "enable"
  server_load_balancer_target_groups  = ["${local.project_name}-lb-ping"] # this will always be <load balancer name>-<load balancer access cidrs key>
  server_direct_access_use_strategy   = "ssh"                             # configure the servers for direct ssh access
  server_access_addresses = {                                             # you must include ssh access here to enable setup
    runnerSsh = {
      port     = 22 # allow access on ssh port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
    runnerKubectl = {
      port     = 6443 # allow access on this port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
  }
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = local.workfolder
    timeout                  = 5
  }
  server_add_domain        = true
  server_domain_name       = each.value["domain"]
  server_domain_zone       = local.zone
  server_add_eip           = false
  install_use_strategy     = local.install_method
  local_file_use_strategy  = local.download
  local_file_path          = "${local.local_file_path}/${each.key}"
  install_rke2_version     = local.rke2_version
  install_rpm_channel      = local.rpm_channel
  install_remote_file_path = "${local.workfolder}/rke2"
  install_role             = "server"
  install_start            = true
  install_prep_script      = local.install_prep_script
  install_start_timeout    = 5
  config_use_strategy      = local.config_strat
  config_default_name      = "50-default-config.yaml"
  config_supplied_content  = local.cni_config
  config_supplied_name     = "51-cni-config.yaml"
  config_join_strategy     = "join"
  config_join_url          = module.initial.join_url
  config_join_token        = module.initial.join_token
  retrieve_kubeconfig      = false
}

module "agents" {
  for_each                            = local.agent_info
  depends_on                          = [module.initial]
  source                              = "../../" # this source is dev use only, see https://registry.terraform.io/modules/rancher/rke2/aws/latest
  project_use_strategy                = "skip"
  server_use_strategy                 = "create"
  server_name                         = each.value["name"]
  server_type                         = "small" # smallest viable control plane node (actually t3.medium)
  server_subnet_name                  = each.value["subnet"]
  server_security_group_name          = "${local.project_name}-sg"
  server_private_ip                   = each.value["ip"]
  server_image_use_strategy           = "find"
  server_image_type                   = local.image
  server_cloudinit_use_strategy       = "skip" # cloud-init not available for sle-micro
  server_indirect_access_use_strategy = "skip" # load balanced access should only be used for servers, not agents
  server_direct_access_use_strategy   = "ssh"  # configure the servers for direct ssh access
  server_access_addresses = {                  # you must include ssh access here to enable setup
    runnerSsh = {
      port     = 22 # allow access on ssh port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
  }
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = local.workfolder
    timeout                  = 5
  }
  server_add_domain        = true
  server_domain_name       = each.value["domain"]
  server_domain_zone       = local.zone
  server_add_eip           = false
  install_use_strategy     = local.install_method
  local_file_use_strategy  = local.download
  local_file_path          = "${local.local_file_path}/${each.key}"
  install_rke2_version     = local.rke2_version
  install_rpm_channel      = local.rpm_channel
  install_remote_file_path = "${local.workfolder}/rke2"
  install_role             = "agent"
  install_start            = true
  install_prep_script      = local.install_prep_script
  install_start_timeout    = 5
  config_use_strategy      = "default"
  config_join_strategy     = "join"
  config_join_url          = module.initial.join_url
  config_join_token        = module.initial.join_token
  retrieve_kubeconfig      = false
}
