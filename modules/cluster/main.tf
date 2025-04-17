
locals {
  # project
  identifier   = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  owner        = var.owner
  project_name = var.project_name
  domain       = var.domain
  zone         = var.zone # DNS zone
  ip_family    = var.ip_family
  skip_cert    = var.skip_cert_creation

  # access
  ssh_key_name = var.key_name
  ssh_key      = trimspace(var.key)
  username     = var.username
  runner_ip    = var.runner_ip

  #rke2
  rke2_version = var.rke2_version
  local_file_path = (
    var.file_path != "" ? (var.file_path == path.root ? "${abspath(path.root)}/rke2" : abspath(var.file_path)) :
    "${abspath(path.root)}/rke2"
  )
  install_method = var.install_method
  download       = (local.install_method == "tar" ? "download" : "skip")
  cni            = var.cni
  # tflint-ignore: terraform_unused_declarations
  ingress_controller = var.ingress_controller # not currently in use, TODO: add traefik functionality

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

  ino                = module.initial[keys(local.initial_node)[0]]
  subnets            = local.ino.project_subnets
  node_configuration = var.node_configuration
  full_node_configs = { for key, node in local.node_configuration :
    key => {
      name            = substr("${local.project_name}-${md5(key)}", 0, 25)
      domain          = substr("${local.project_name}-${md5(key)}", 0, 25)
      indirect_access = (node.indirect_access ? "enable" : "skip")
      file_path       = "${local.local_file_path}/${substr("${local.project_name}-${md5(key)}", 0, 25)}/data"
      path            = "${local.local_file_path}/${substr("${local.project_name}-${md5(key)}", 0, 25)}"
      config = (
        strcontains(node.type, "all-in-one") ? local.all_in_one_config :
        strcontains(node.type, "control-plane") ? local.control_plane_config :
        strcontains(node.type, "api") ? local.api_config :
        strcontains(node.type, "database") ? local.database_config :
        "" # worker nodes don't need additional config
      )
      config_strategy = "merge"
      role            = node.type
      type            = (strcontains(node.type, "worker") ? "agent" : "server")
      size            = node.size
      image           = node.os
      prep_script = (
        strcontains(node.os, "sles") ? templatefile("${path.module}/suse_prep.sh", {
          install_method = local.install_method,
          ip_family      = local.ip_family,
          image          = node.os,
        }) :
        strcontains(node.os, "rhel") ? templatefile("${path.module}/rhel_prep.sh", {
          install_method = local.install_method,
          ip_family      = local.ip_family,
          image          = node.os,
        }) :
        strcontains(node.os, "ubuntu") ? templatefile("${path.module}/ubuntu_prep.sh", {
          install_method = local.install_method,
          ip_family      = local.ip_family,
          image          = node.os,
        }) :
        (strcontains(node.os, "sle-micro-60") || strcontains(node.os, "sle-micro-61")) ? templatefile("${path.module}/slem60_61_prep.sh", {
          install_method = local.install_method,
          ip_family      = local.ip_family,
          image          = node.os,
        }) :
        ""
      )
      start_prep_script = (
        # (strcontains(node.os, "sle-micro-60") || strcontains(node.os, "sle-micro-61")) ? file("${path.module}/slem60_61_start_prep.sh") :
        ""
      )
      initial            = node.initial
      workfolder         = strcontains(node.os, "cis") ? "/var/tmp" : "/home/${local.username}"
      cloudinit_strategy = (node.os == "sle-micro-55" || node.os == "cis-rhel-8") ? "skip" : "default"
      # CIS images are not supported on IPv6 only deployments due to kernel modifications with how AWS IPv6 works (dhcpv6)
      # tflint-ignore: terraform_unused_declarations
      fail_cis_ipv6 = ((node.os == "rhel-8-cis" && local.ip_family == "ipv6") ? one([local.ip_family, "cis_ipv6_incompatible"]) : false)
      # Ubuntu images do not support rpm install method
      # tflint-ignore: terraform_unused_declarations
      fail_ubuntu_rpm = ((strcontains(node.os, "ubuntu") && local.install_method == "rpm") ? one([local.install_method, "ubuntu_rpm_incompatible"]) : false)
    }
  }
  target_groups = {
    kubectl              = substr(lower("${local.project_name}-kubectl"), 0, 32)
    application-secure   = substr(lower("${local.project_name}-application-secure"), 0, 32)
    application-insecure = substr(lower("${local.project_name}-application-insecure"), 0, 32)
  }
  initial_node = { for k, v in local.full_node_configs : k => v if v.initial == true }
  additional_nodes = {
    for k, v in local.full_node_configs :
    k => merge(
      v,
      tomap({ az = local.subnets[keys(local.subnets)[index(keys(local.full_node_configs), k) % length(local.subnets)]].availability_zone }),
      tomap({ subnet = local.subnets[keys(local.subnets)[index(keys(local.full_node_configs), k) % length(local.subnets)]].tags.Name })
    )
    if v.initial != true
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "initial" {
  depends_on = [
    data.aws_availability_zones.available,
  ]
  source                              = "rancher/rke2/aws"
  version                             = "1.2.2"
  for_each                            = local.initial_node
  project_use_strategy                = "create"
  project_vpc_use_strategy            = "create"
  project_vpc_name                    = "${local.project_name}-vpc"
  project_vpc_zones                   = data.aws_availability_zones.available.names
  project_vpc_type                    = local.ip_family
  project_vpc_public                  = local.ip_family == "ipv6" ? false : true # ipv6 addresses assigned by AWS are always public
  project_subnet_use_strategy         = "create"
  project_subnet_names                = [for z in data.aws_availability_zones.available.names : "${local.project_name}-subnet-${z}"]
  project_security_group_use_strategy = "create"
  project_security_group_name         = "${local.project_name}-sg"
  project_security_group_type         = "egress" # in the future we should allow this to be variable, but we need to figure out airgap first
  project_load_balancer_use_strategy  = "create"
  project_load_balancer_name          = "${local.project_name}-lb"
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
  project_domain_use_strategy         = "create"
  project_domain                      = local.domain
  project_domain_zone                 = local.zone
  project_domain_cert_use_strategy    = (local.skip_cert ? "skip" : "create")
  server_use_strategy                 = "create"
  server_name                         = each.value.name
  server_type                         = each.value.size
  server_availability_zone            = data.aws_availability_zones.available.names[0]
  server_image_use_strategy           = "find"
  server_image_type                   = each.value.image
  server_ip_family                    = local.ip_family
  server_cloudinit_use_strategy       = each.value.cloudinit_strategy
  server_indirect_access_use_strategy = each.value.indirect_access
  server_load_balancer_target_groups  = values(local.target_groups)
  server_direct_access_use_strategy   = "ssh" # configure the servers for direct ssh access
  #https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements/port-requirements#rancher-aws-ec2-security-group
  server_access_addresses = { # you must include ssh access here to enable setup
    ssh = {
      port      = 22 # allow runner access on ssh port
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
  #server_load_balancer_target_groups = values(local.target_groups) first node is an etcd node, not an API node, we use the internal LB for that
  server_user = {
    user                     = local.username
    aws_keypair_use_strategy = "select"
    ssh_key_name             = local.ssh_key_name
    public_ssh_key           = local.ssh_key
    user_workfolder          = each.value.workfolder
    timeout                  = 10
  }
  server_add_domain         = false
  server_domain_name        = each.value.domain
  server_domain_zone        = local.zone
  server_add_eip            = false
  install_use_strategy      = local.install_method
  local_file_use_strategy   = local.download
  local_file_path           = each.value.file_path
  install_rke2_version      = local.rke2_version
  install_rpm_channel       = "stable"
  install_remote_file_path  = "${each.value.workfolder}/rke2"
  install_role              = each.value.type
  install_start             = true
  install_prep_script       = each.value.prep_script
  install_start_prep_script = each.value.start_prep_script
  install_start_timeout     = 10
  config_use_strategy       = each.value.config_strategy
  config_join_strategy      = "skip"
  config_default_name       = "50-default-config.yaml"
  config_supplied_name      = "51-config.yaml"
  config_supplied_content   = each.value.config
  retrieve_kubeconfig       = true
}

# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# In this example I am using Terraform resources to orchestrate Terraform
#   I felt this was the best way to accomplish the goal without incurring additional dependencies
# The configuration we are orchestrating isn't hard coded, we will be generating the config from a templatefile
#  see "local_file.cp_main"
resource "terraform_data" "path" {
  depends_on = [
    module.initial,
  ]
  for_each = local.additional_nodes
  triggers_replace = {
    initial_token = local.ino.join_token
    initial_url   = local.ino.join_url
  }
  provisioner "local-exec" {
    command = <<-EOT
      install -d ${each.value.path}
      cp ${abspath(path.module)}/variables.tf ${each.value.path}
      cp ${abspath(path.module)}/versions.tf  ${each.value.path}
    EOT
  }
}
resource "local_file" "main" {
  depends_on = [
    module.initial,
    terraform_data.path,
  ]
  for_each = local.additional_nodes
  content = templatefile(
    "${abspath(path.module)}/main.tf.tftpl",
    {
      project_security_group_name = local.ino.project_security_group.name
      project_subnets             = jsonencode(local.ino.project_subnets)
      join_url                    = local.ino.join_url
      join_token                  = local.ino.join_token
      cluster_cidr                = jsonencode(local.ino.cluster_cidr)
      service_cidr                = jsonencode(local.ino.service_cidr)
      server_info                 = jsonencode(each.value)
      role                        = each.value.role # worker, control-plane, database, all-in-one, etc
      target_groups               = jsonencode(local.target_groups)
    }
  )
  filename = "${each.value.path}/main.tf"
}
resource "local_file" "inputs" {
  depends_on = [
    module.initial,
    terraform_data.path,
    local_file.main,
  ]
  for_each = local.additional_nodes
  content  = <<-EOT
    identifier         = "${local.identifier}"
    owner              = "${local.owner}"
    project_name       = "${local.project_name}"
    domain             = "${local.domain}"
    zone               = "${local.zone}"
    key_name           = "${local.ssh_key_name}"
    key                = "${local.ssh_key}"
    username           = "${local.username}"
    runner_ip          = "${local.runner_ip}"
    rke2_version       = "${local.rke2_version}"
    file_path          = "${each.value.file_path}"
    install_method     = "${local.install_method}"
    cni                = "${local.cni}"
    ip_family          = "${local.ip_family}"
    ingress_controller = "${local.ingress_controller}"
  EOT
  filename = "${each.value.path}/inputs.tfvars"
}

resource "terraform_data" "create" {
  depends_on = [
    module.initial,
    terraform_data.path,
    local_file.main,
    local_file.inputs,
  ]
  for_each = local.additional_nodes
  triggers_replace = {
    initial = local.ino.join_url
    path    = each.value.path
  }
  provisioner "local-exec" {
    command = <<-EOT
      cd ${self.triggers_replace.path}
      TF_DATA_DIR="${self.triggers_replace.path}"
      terraform init -upgrade=true
      EXITCODE=1
      ATTEMPTS=0
      MAX=3
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        echo "Starting attempt $((ATTEMPTS + 1))..."
        timeout 1h terraform apply -var-file="inputs.tfvars" -auto-approve -state="${self.triggers_replace.path}/tfstate"
        EXITCODE=$?
        if [ $EXITCODE -eq 124 ]; then echo "Apply timed out after 1 hour"; fi
        ATTEMPTS=$((ATTEMPTS + 1))
        echo "Exit code $EXITCODE..."
        if [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; then
          echo "wait 30 seconds between attempts..."
          sleep 30
        fi
      done
      exit $EXITCODE
    EOT
  }
  provisioner "local-exec" {
    # warning! this is only triggered on destroy, not refresh/taint
    when    = destroy
    command = <<-EOT
      set -x
      cd ${self.triggers_replace.path}
      TF_DATA_DIR="${self.triggers_replace.path}"
      EXITCODE=1
      ATTEMPTS=0
      MAX=3
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        echo "Starting attempt $((ATTEMPTS + 1))..."
        timeout 1h terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="${self.triggers_replace.path}/tfstate"
        EXITCODE=$?
        if [ $EXITCODE -eq 124 ]; then echo "Apply timed out after 1 hour"; fi
        ATTEMPTS=$((ATTEMPTS + 1))
        echo "Exit code $EXITCODE..."
        if [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; then
          echo "wait 30 seconds between attempts..."
          sleep 30
        fi
      done
      exit $EXITCODE
    EOT
  }
}

resource "local_file" "kubeconfig" {
  depends_on = [
    module.initial,
    terraform_data.path,
    local_file.main,
    local_file.inputs,
    terraform_data.create,
  ]
  content  = local.ino.kubeconfig
  filename = "${local.local_file_path}/kubeconfig"
}
# commented for performance, leaving to show how you can export the state if necessary
# data "terraform_remote_state" "additional_node_states" {
#   depends_on = [
#     module.initial,
#     terraform_data.path,
#     local_file.main,
#     local_file.inputs,
#     terraform_data.create,
#   ]
#   for_each = local.additional_nodes
#   backend  = "local"
#   config = {
#     path = "${each.value.path}/tfstate"
#   }
# }
