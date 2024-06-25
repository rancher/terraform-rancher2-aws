locals {
  # requested vars
  project_name    = var.project_name
  ssh_key_name    = var.key_name
  ssh_key         = var.key
  username        = var.username
  vpc_cidr        = var.vpc_cidr
  zone            = var.zone
  domain          = var.domain
  fqdn            = lower("${local.domain}.${local.zone}")
  rke2_version    = var.rke2_version
  image           = var.os
  local_file_path = var.local_file_path
  #local_file_path = (var.file_path != "" ? (var.file_path == path.root ? "${abspath(path.root)}/rke2" : var.file_path) : "${abspath(path.root)}/rke2")
  workfolder = var.workfolder
  #workfolder = (strcontains(local.image, "cis") ? "/var/tmp" : "/home/${local.username}")
  install_method = var.install_method
  cni            = var.cni
  cluster_size   = var.cluster_size
  runner_ip      = var.admin_ip

  # derived vars
  install_prep_script = (
    strcontains(local.image, "sles-15") ? file("${path.module}/suse_prep.sh") : (
      strcontains(local.image, "ubuntu") ? file("${path.module}/ubuntu_prep.sh") : (
        strcontains(local.image, "rhel") ? file("${path.module}/rhel_prep.sh") :
      "")
  ))
  config_strat = (local.cni == "canal" ? "default" : "merge")
  cni_config = (
    local.cni == "cilium" ? file("${path.module}/cilium.yaml") : (
      local.cni == "calico" ? file("${path.module}/calico.yaml") :
    "")
  )
  download = (local.install_method == "tar" ? "download" : "skip")

  # cluster scale options
  server_ids = [for i in range(local.cluster_size) : "${local.project_name}-${substr(md5(uuidv5("dns", tostring(i))), 0, 4)}"]
  project_subnets = { for i in range(length(data.aws_availability_zones.available.names)) : # for every availability zone, create a subnet
    "${data.aws_availability_zones.available.names[i]}-${local.project_name}" => {
      "cidr"              = cidrsubnet(local.vpc_cidr, (length(data.aws_availability_zones.available.names) - 1), (i))
      "availability_zone" = data.aws_availability_zones.available.names[i]
      public              = true
    }
  }
  server_subnets = { for i in range(local.cluster_size) : # assign each server to a subnet, cycle through subnets
    local.server_ids[i] => "${data.aws_availability_zones.available.names[i % length(data.aws_availability_zones.available.names)]}-${local.project_name}"
  }
  subnet_servers = { for subnet, servers in
    { for server, subnet in local.server_subnets : subnet => [for k, v in local.server_subnets : k if v == subnet]... } :
    subnet => flatten(setunion(servers))
  }
  server_ips = { for i in range(local.cluster_size) :
    # local.server_subnets[server_ids[i]] = subnet id which is ("${data.aws_availability_zones.available.names[i]}-sn") eg. "us-west-2b-sn"
    local.server_ids[i] => cidrhost(
      local.project_subnets[local.server_subnets[local.server_ids[i]]]["cidr"],
      index(local.subnet_servers[local.server_subnets[local.server_ids[i]]], local.server_ids[i]) + 6
    )
  }
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
}

data "aws_availability_zones" "available" {
  state = "available"
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
  project_domain_use_strategy         = "create"
  project_domain                      = local.fqdn
  project_load_balancer_access_cidrs = {
    rancherGui = {
      port     = "443"
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to ping service from this CIDR only
    }
    rancherApi = {
      port     = "6443"
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to ping service from this CIDR only
    }
  }
  server_use_strategy                 = "create"
  server_name                         = local.initial_server_info["name"]
  server_type                         = "medium"
  server_subnet_name                  = local.initial_server_info["subnet"]
  server_security_group_name          = "${local.project_name}-sg"
  server_private_ip                   = local.initial_server_info["ip"]
  server_image_use_strategy           = "find"
  server_image_type                   = local.image
  server_cloudinit_use_strategy       = "skip" # cloud-init not available for sle-micro
  server_indirect_access_use_strategy = "enable"
  server_load_balancer_target_groups  = ["${local.project_name}-lb-rancherGui", "${local.project_name}-lb-rancherApi"] # this will always be <load balancer name>-<load balancer access cidrs key>
  server_direct_access_use_strategy   = "ssh"                                                                          # configure the servers for direct ssh access
  server_access_addresses = {                                                                                          # you must include ssh access here to enable setup
    runner-ssh = {
      port     = 22 # allow access on ssh port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
    runner-kubectl = {
      port     = 6443 # allow access on this port only
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
    runner-rancher-gui = {
      port     = 443 # allow access on this port only
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
  install_rpm_channel      = "stable"
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
  source                              = "rancher/rke2/aws"
  version                             = "1.0.0"
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
  server_load_balancer_target_groups  = ["${local.project_name}-lb-rancherGui", "${local.project_name}-lb-rancherApi"] # this will always be <load balancer name>-<load balancer access cidrs key>
  server_direct_access_use_strategy   = "ssh"                                                                          # configure the servers for direct ssh access
  server_access_addresses = {                                                                                          # you must include ssh access here to enable setup
    runnerSsh = {
      port     = 22
      protocol = "tcp"
      cidrs    = ["${local.runner_ip}/32"] # allow access to this CIDR only
    }
    runnerKubectl = {
      port     = 6443
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
  install_rpm_channel      = "stable"
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

resource "local_sensitive_file" "kubeconfig" {
  depends_on = [module.initial]
  content    = module.initial.kubeconfig
  filename   = "${local.local_file_path}/kubeconfig"
}
