
locals {
  # project
  identifier      = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  owner           = var.owner
  project_name    = var.project_name
  domain          = var.domain
  zone            = var.zone # DNS zone
  ip_family       = var.ip_family
  skip_cert       = var.skip_cert_creation
  acme_server_url = var.acme_server_url

  # access
  ssh_key_name = var.key_name
  ssh_key      = trimspace(var.key)
  username     = var.username
  runner_ip    = var.runner_ip

  # server
  node_configuration = var.node_configuration

  #rke2
  rke2_version = var.rke2_version
  local_file_path = (
    var.file_path != "" ? (var.file_path == path.root ? "${path.root}/rke2" : var.file_path) :
    "${path.root}/rke2"
  )

  install_method       = var.install_method
  download             = (local.install_method == "tar" ? "download" : "skip")
  cni                  = var.cni
  cni_file             = (local.cni == "cilium" ? "${path.root}/cilium.yaml" : (local.cni == "calico" ? "${path.root}/calico.yaml" : ""))
  cni_config           = (local.cni_file != "" ? file(local.cni_file) : "")
  api_config           = <<-EOT
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
    disable-etcd: true
    ${local.cni_config}
  EOT
  database_config      = <<-EOT
    disable-apiserver: true
    disable-controller-manager: true
    disable-scheduler: true
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
  EOT
  control_plane_config = <<-EOT
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
    ${local.cni_config}
  EOT
  all_in_one_config    = <<-EOT
    ${local.cni_config}
  EOT

  ino     = module.deploy_initial_node[keys(local.initial_node)[0]]
  subnets = local.ino.output.project_subnets
  all_nodes = {
    for k, v in local.node_configuration :
    k => merge(
      v,
      {
        deploy_path = "${local.local_file_path}/tf-nodes/${substr("${local.project_name}-${md5(k)}", 0, 25)}"
      },
    )
  }
  initial_node     = { for k, v in local.all_nodes : k => v if v.initial == true }
  additional_nodes = { for k, v in local.all_nodes : k => v if v.initial != true }

  target_groups = {
    kubectl              = substr(lower("${local.project_name}-kubectl"), 0, 32)
    application-secure   = substr(lower("${local.project_name}-application-secure"), 0, 32)
    application-insecure = substr(lower("${local.project_name}-application-insecure"), 0, 32)
  }

  # remember these are external access objects, internal access is enabled by default
  # https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements/port-requirements#rancher-aws-ec2-security-group
  server_access_addresses = { # you must include ssh access here to enable setup
    ssh = {
      port      = 22 # allow access on ssh port
      protocol  = "tcp"
      ip_family = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs     = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
    }
    api = {
      port      = 6443 # allow runner IP access to API
      protocol  = "tcp"
      ip_family = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs     = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
    }
    application-secure = {
      port      = 443 # allow runner IP access to https
      protocol  = "tcp"
      ip_family = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs     = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
    }
    application-insecure = {
      port      = 80 # allow runner IP access to http
      protocol  = "tcp"
      ip_family = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs     = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
    }
  }
  project_load_balancer_access_cidrs = {
    "kubectl" = {
      port        = "6443"
      protocol    = "tcp"
      ip_family   = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs       = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
      target_name = local.target_groups.kubectl
    }
    "application-secure" = {
      port        = "443"
      protocol    = "tcp"
      ip_family   = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs       = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
      target_name = local.target_groups.application-secure
    }
    "application-insecure" = {
      port        = "80"
      protocol    = "tcp"
      ip_family   = (local.ip_family == "ipv6" ? "ipv6" : "ipv4")
      cidrs       = (local.ip_family == "ipv6" ? ["${local.runner_ip}/128"] : ["${local.runner_ip}/32"])
      target_name = local.target_groups.application-insecure
    }
  }
  project_subnet_names = [for z in data.aws_availability_zones.available.names : "${local.project_name}-subnet-${z}"]
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "deploy_initial_node" {
  source = "../deploy"
  depends_on = [
    data.aws_availability_zones.available,
  ]
  for_each    = local.initial_node
  deploy_path = each.value.deploy_path
  data_path   = each.value.deploy_path
  # if any of this changes, update/redeploy
  deploy_trigger = md5(join("-", [
    each.key,
    md5(base64encode(jsonencode(each.value))),
    local.identifier,
    local.owner,
    local.acme_server_url,
    local.project_name,
    local.ip_family,
    md5(base64encode(jsonencode(data.aws_availability_zones.available.names))),
    md5(base64encode(jsonencode(local.project_subnet_names))),
    md5(base64encode(jsonencode(local.project_load_balancer_access_cidrs))),
    local.domain,
    local.zone,
    local.skip_cert,
    data.aws_availability_zones.available.names[0],
    md5(base64encode(jsonencode(values(local.target_groups)))),
    md5(base64encode(jsonencode(local.server_access_addresses))),
    local.username,
    local.ssh_key,
    local.install_method,
    local.download,
    local.rke2_version,
  ]))
  template_files = [
    join("/", [path.module, "node_template", "main.tf"]),
    join("/", [path.module, "node_template", "outputs.tf"]),
    join("/", [path.module, "node_template", "variables.tf"]),
    join("/", [path.module, "node_template", "versions.tf"]),
  ]
  inputs = <<-EOT
    identifier                          = "${local.identifier}"
    owner                               = "${local.owner}"
    acme_server_url                     = "${local.acme_server_url}"
    project_use_strategy                = "create"
    project_name                        = "${local.project_name}"
    project_vpc_use_strategy            = "create"
    project_vpc_type                    = "${local.ip_family}"
    project_vpc_zones                   = "${base64encode(jsonencode(data.aws_availability_zones.available.names))}"
    project_vpc_public                  = "${local.ip_family == "ipv6" ? "false" : "true"}" # ipv6 addresses assigned by AWS are always public
    project_subnet_use_strategy         = "create"
    project_subnet_names                = "${base64encode(jsonencode(local.project_subnet_names))}"
    project_security_group_use_strategy = "create"
    project_security_group_type         = "egress" # in the future we should allow this to be variable, but we need to figure out airgap first
    project_load_balancer_use_strategy  = "create"
    project_load_balancer_access_cidrs  = "${base64encode(jsonencode(local.project_load_balancer_access_cidrs))}"
    project_domain_use_strategy         = "create"
    project_domain                      = "${local.domain}"
    project_domain_zone                 = "${local.zone}"
    project_domain_cert_use_strategy    = "${(local.skip_cert ? "skip" : "create")}"
    server_name                         = "${substr("${local.project_name}-${md5(each.key)}", 0, 25)}"
    server_type                         = "${each.value.size}"
    server_ip_family                    = "${local.ip_family}"
    server_availability_zone            = "${data.aws_availability_zones.available.names[0]}"
    server_image_type                   = "${each.value.os}"
    server_cloudinit_use_strategy       = "${(each.value.os == "sle-micro-55" || each.value.os == "cis-rhel-8") ? "skip" : "default"}"
    server_indirect_access_use_strategy = "${(each.value.indirect_access ? "enable" : "skip")}"
    server_load_balancer_target_groups  = "${base64encode(jsonencode(values(local.target_groups)))}"
    server_access_addresses             = "${base64encode(jsonencode(local.server_access_addresses))}"
    server_user                         = "${base64encode(jsonencode({
  user                     = local.username
  aws_keypair_use_strategy = "select"
  ssh_key_name             = local.ssh_key_name
  public_ssh_key           = local.ssh_key
  user_workfolder          = strcontains(each.value.os, "cis") ? "/var/tmp" : "/home/${local.username}"
  timeout                  = 10
}))}"
    server_add_domain        = false
    install_use_strategy     = "${local.install_method}"
    local_file_use_strategy  = "${local.download}"
    local_file_path          = "${each.value.deploy_path}/configs"
    install_rke2_version     = "${local.rke2_version}"
    install_remote_file_path = "${join("/", [(strcontains(each.value.os, "cis") ? "/var/tmp" : "/home/${local.username}"), "rke2"])}"
    install_prep_script      = "${base64encode((
strcontains(each.value.os, "sles") ? templatefile("${path.module}/suse_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
strcontains(each.value.os, "rhel") ? templatefile("${path.module}/rhel_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
strcontains(each.value.os, "ubuntu") ? templatefile("${path.module}/ubuntu_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
(strcontains(each.value.os, "sle-micro-60") || strcontains(each.value.os, "sle-micro-61")) ? templatefile("${path.module}/slem60_61_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
""
))}"
    install_role            = "${(strcontains(each.value.type, "worker") ? "agent" : "server")}"
    config_supplied_content = "${base64encode((
strcontains(each.value.type, "all-in-one") ? local.all_in_one_config :
strcontains(each.value.type, "control-plane") ? local.control_plane_config :
strcontains(each.value.type, "api") ? local.api_config :
strcontains(each.value.type, "database") ? local.database_config :
"" # worker nodes don't need additional config
))}"
    config_supplied_name = "51-config.yaml"
    config_join_strategy = "skip"
    retrieve_kubeconfig  = "true"
  EOT
}

# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# In this module I am using Terraform resources to orchestrate Terraform
#   I felt this was the best way to accomplish the goal without incurring additional dependencies
module "deploy_additional_nodes" {
  source = "../deploy"
  depends_on = [
    data.aws_availability_zones.available,
    module.deploy_initial_node,
  ]
  for_each    = local.additional_nodes
  deploy_path = each.value.deploy_path
  data_path   = each.value.deploy_path
  # if any of this changes, update/redeploy
  deploy_trigger = md5(join("-", [
    each.key,
    md5(base64encode(jsonencode(each.value))),
    local.identifier,
    local.owner,
    local.acme_server_url,
    local.project_name,
    local.ip_family,
    md5(base64encode(jsonencode(data.aws_availability_zones.available.names))),
    md5(base64encode(jsonencode(local.project_subnet_names))),
    md5(base64encode(jsonencode(local.project_load_balancer_access_cidrs))),
    local.domain,
    local.zone,
    local.skip_cert,
    data.aws_availability_zones.available.names[0],
    md5(base64encode(jsonencode(values(local.target_groups)))),
    md5(base64encode(jsonencode(local.server_access_addresses))),
    local.username,
    local.ssh_key,
    local.install_method,
    local.download,
    local.rke2_version,
  ]))
  template_files = [
    join("/", [path.module, "node_template", "main.tf"]),
    join("/", [path.module, "node_template", "outputs.tf"]),
    join("/", [path.module, "node_template", "variables.tf"]),
    join("/", [path.module, "node_template", "versions.tf"]),
  ]
  inputs = <<-EOT
    identifier                  = "${local.identifier}"
    owner                       = "${local.owner}"
    acme_server_url             = "${local.acme_server_url}"
    project_use_strategy        = "skip"
    project_domain              = "${local.domain}"
    project_domain_zone         = "${local.zone}"
    project_security_group_name = "${local.ino.output.project_security_group.name}"
    server_name                 = "${substr("${local.project_name}-${md5(each.key)}", 0, 25)}"
    server_type                 = "${each.value.size}"
    server_ip_family            = "${local.ip_family}"
    # the availability zone of the subnet with index matching the modulo of the index of the current key and the total number of subnets
    #   so current key index % length of subnets = the index of the subnet that we will get the availability zone of
    #   ex1. key index = 1, subnets length = 3; subnet[2].availability_zone, subnet[2].tags.Name
    #   ex2. key index = 5, subnets length = 3; subnet[1].availability_zone, subnet[1].tags.Name
    # this creates round robin distribution of nodes across availability zones
    server_availability_zone            = "${local.subnets[keys(local.subnets)[index(keys(local.additional_nodes), each.key) % length(local.subnets)]].availability_zone}"
    server_subnet_name                  = "${local.subnets[keys(local.subnets)[index(keys(local.additional_nodes), each.key) % length(local.subnets)]].tags.Name}"
    server_security_group_name          = "${local.ino.output.project_security_group.name}"
    server_image_type                   = "${each.value.os}"
    server_cloudinit_use_strategy       = "${(each.value.os == "sle-micro-55" || each.value.os == "cis-rhel-8") ? "skip" : "default"}"
    server_indirect_access_use_strategy = "${(each.value.indirect_access ? "enable" : "skip")}"
    server_load_balancer_target_groups  = "${base64encode(jsonencode(values(local.target_groups)))}"
    server_access_addresses             = "${base64encode(jsonencode(local.server_access_addresses))}"
    server_user                         = "${base64encode(jsonencode({
  user                     = local.username
  aws_keypair_use_strategy = "select"
  ssh_key_name             = local.ssh_key_name
  public_ssh_key           = local.ssh_key
  user_workfolder          = strcontains(each.value.os, "cis") ? "/var/tmp" : "/home/${local.username}"
  timeout                  = 10
}))}"
    server_add_domain        = false
    install_use_strategy     = "${local.install_method}"
    local_file_use_strategy  = "${local.download}"
    local_file_path          = "${each.value.deploy_path}/configs"
    install_rke2_version     = "${local.rke2_version}"
    install_remote_file_path = "${join("/", [(strcontains(each.value.os, "cis") ? "/var/tmp" : "/home/${local.username}"), "rke2"])}"
    install_prep_script      = "${base64encode((
strcontains(each.value.os, "sles") ? templatefile("${path.module}/suse_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
strcontains(each.value.os, "rhel") ? templatefile("${path.module}/rhel_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
strcontains(each.value.os, "ubuntu") ? templatefile("${path.module}/ubuntu_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
(strcontains(each.value.os, "sle-micro-60") || strcontains(each.value.os, "sle-micro-61")) ? templatefile("${path.module}/slem60_61_prep.sh", {
  install_method = local.install_method,
  ip_family      = local.ip_family,
  image          = each.value.os,
}) :
""
))}"
    install_role            = "${(strcontains(each.value.type, "worker") ? "agent" : "server")}"
    config_supplied_content = "${base64encode((
strcontains(each.value.type, "all-in-one") ? local.all_in_one_config :
strcontains(each.value.type, "control-plane") ? local.control_plane_config :
strcontains(each.value.type, "api") ? local.api_config :
strcontains(each.value.type, "database") ? local.database_config :
"" # worker nodes don't need additional config
))}"
    config_supplied_name = "51-config.yaml"
    config_join_strategy = "join"
    config_join_url      = "${local.ino.output.join_url}"
    config_join_token    = "${local.ino.output.join_token}"
    config_cluster_cidr  = "${base64encode(jsonencode(local.ino.output.cluster_cidr))}"
    config_service_cidr  = "${base64encode(jsonencode(local.ino.output.service_cidr))}"
  EOT
}

resource "file_local" "kubeconfig" {
  depends_on = [
    module.deploy_initial_node,
    module.deploy_additional_nodes,
  ]
  name      = "kubeconfig"
  directory = local.local_file_path
  contents  = local.ino.output.kubeconfig
}
