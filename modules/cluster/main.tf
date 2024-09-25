
locals {
  # tflint-ignore: terraform_unused_declarations
  ingress_controller = var.ingress_controller # not currently in use, TODO: add traefik functionality
  cp_count           = var.api_nodes
  db_count           = var.database_nodes
  worker_count       = var.worker_nodes
  identifier         = var.identifier # this is a random unique string that can be used to identify resources in the cloud provider
  owner              = var.owner
  project_name       = var.project_name
  username           = var.username
  ip_family          = var.ip_family
  runner_ip          = var.runner_ip
  ssh_key            = trimspace(var.key)
  ssh_key_name       = var.key_name
  zone               = var.zone # DNS zone
  domain             = var.domain
  rke2_version       = var.rke2_version
  image              = var.os
  rancher_size       = var.size
  worker_server_type = (
    local.rancher_size == "small" ? "xl" :
    local.rancher_size == "medium" ? "xxl" :
    local.rancher_size == "large" ? "xxxl" :
    ""
  )
  install_method = var.install_method
  install_prep_script_file = (
    strcontains(local.image, "sles") ? "${path.root}/suse_prep.sh" :
    strcontains(local.image, "rhel") ? "${path.root}/rhel_prep.sh" :
    strcontains(local.image, "ubuntu") ? "${path.root}/ubuntu_prep.sh" :
    ""
  )
  install_prep_script = (local.install_prep_script_file == "" ? "" :
    templatefile(local.install_prep_script_file, {
      install_method = local.install_method,
      ip_family      = local.ip_family,
      image          = local.image,
    })
  )
  download     = (local.install_method == "tar" ? "download" : "skip")
  cni          = var.cni
  config_strat = "merge"
  cni_file     = (local.cni == "cilium" ? "${path.root}/cilium.yaml" : (local.cni == "calico" ? "${path.root}/calico.yaml" : ""))
  cni_config   = (local.cni_file != "" ? file(local.cni_file) : "")
  # WARNING! Local file path needs to be isolated, don't use the same path as your terraform files
  local_file_path = (
    var.file_path != "" ? (var.file_path == path.root ? "${abspath(path.root)}/rke2" : abspath(var.file_path)) :
    "${abspath(path.root)}/rke2"
  )
  workfolder = (strcontains(local.image, "cis") ? "/var/tmp" : "/home/${local.username}")
  target_groups = {
    kubectl              = substr(lower("${local.project_name}-kubectl"), 0, 32)
    application-secure   = substr(lower("${local.project_name}-application-secure"), 0, 32)
    application-insecure = substr(lower("${local.project_name}-application-insecure"), 0, 32)
  }
  cloudinit_strategy = ((local.image == "sle-micro-55" || local.image == "cis-rhel-8") ? "skip" : "default")
  # CIS images are not supported on IPv6 only deployments due to kernel modifications with how AWS IPv6 works (dhcpv6)
  # tflint-ignore: terraform_unused_declarations
  fail_cis_ipv6 = ((local.image == "rhel-8-cis" && local.ip_family == "ipv6") ? one([local.ip_family, "cis_ipv6_incompatible"]) : false)
  # Ubuntu images do not support rpm unstall method
  # tflint-ignore: terraform_unused_declarations
  fail_ubuntu_rpm = ((strcontains(local.image, "ubuntu") && local.install_method == "rpm") ? one([local.install_method, "ubuntu_rpm_incompatible"]) : false)

  # cluster scale options
  # cp is a control_plane node that doesn't serve etcd
  # db is a control_plane node that only serves etcd (we may also add options to serve kine with a different db in the future)
  # agent is a worker node that only runs the rke2 agent
  cp_config = <<-EOT
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
    disable-etcd: true
    ${local.cni_config}
  EOT
  db_config = <<-EOT
    disable-apiserver: true
    disable-controller-manager: true
    disable-scheduler: true
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
  EOT

  initial_server_id = substr("${local.project_name}-${md5("initial")}", 0, 25)
  initial_server_info = {
    name      = local.initial_server_id
    domain    = "${local.initial_server_id}.${local.zone}"
    az        = data.aws_availability_zones.available.names[0]
    file_path = "${local.local_file_path}/${local.initial_server_id}/data"
    config    = local.db_config
    size      = "medium"
  }

  subnets = [for s in module.initial.project_subnets : s]

  db_ids = tolist([for i in range(1, local.db_count) : substr("${local.project_name}-${substr(md5(uuidv5("dns", join("-", [tostring(i), "db"]))), 0, 4)}", 0, 25)])
  db_info = {
    for i in range(local.db_count - 1) :
    local.db_ids[i] => {
      name      = local.db_ids[i]
      domain    = "${local.db_ids[i]}.${local.zone}"
      subnet    = local.subnets[(i % length(local.subnets))].tags.Name
      az        = local.subnets[(i % length(local.subnets))].availability_zone
      file_path = "${local.local_file_path}/${local.db_ids[i]}/data"
      path      = "${local.local_file_path}/${local.db_ids[i]}"
      config    = local.db_config
      type      = "server"
      role      = "database"
      size      = "medium"
    }
  }
  cp_ids = [for i in range(local.cp_count) : substr("${local.project_name}-${substr(md5(uuidv5("dns", join("-", [tostring(i), "cp"]))), 0, 4)}", 0, 25)]
  cp_info = {
    for i in range(local.cp_count) :
    local.cp_ids[i] => {
      name      = local.cp_ids[i]
      domain    = "${local.cp_ids[i]}.${local.zone}"
      subnet    = local.subnets[(i % length(local.subnets))].tags.Name
      az        = local.subnets[(i % length(local.subnets))].availability_zone
      file_path = "${local.local_file_path}/${local.cp_ids[i]}/data"
      path      = "${local.local_file_path}/${local.cp_ids[i]}"
      config    = local.cp_config
      type      = "server"
      role      = "control_plane"
      size      = "medium"
    }
  }

  worker_ids = [for i in range(local.worker_count) : substr("${local.project_name}-${substr(md5(uuidv5("dns", join("-", [tostring(i), "wrk"]))), 0, 4)}", 0, 25)]
  worker_info = {
    for i in range(local.worker_count) :
    local.worker_ids[i] => {
      name      = local.worker_ids[i]
      domain    = "${local.worker_ids[i]}.${local.zone}"
      subnet    = local.subnets[(i % length(local.subnets))].tags.Name
      az        = local.subnets[(i % length(local.subnets))].availability_zone
      file_path = "${local.local_file_path}/${local.worker_ids[i]}/data"
      path      = "${local.local_file_path}/${local.worker_ids[i]}"
      config    = ""
      type      = "agent"
      role      = "worker"
      size      = local.worker_server_type
    }
  }
}

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "initial" {
  source                              = "rancher/rke2/aws"
  version                             = "1.1.7"
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
  project_domain_cert_use_strategy    = "create"
  server_use_strategy                 = "create"
  server_name                         = local.initial_server_info["name"]
  server_type                         = local.initial_server_info["size"]
  server_availability_zone            = local.initial_server_info["az"]
  server_image_use_strategy           = "find"
  server_image_type                   = local.image
  server_ip_family                    = local.ip_family
  server_cloudinit_use_strategy       = local.cloudinit_strategy
  server_indirect_access_use_strategy = "enable"
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
    user_workfolder          = local.workfolder
    timeout                  = 10
  }
  server_add_domain        = false
  server_domain_name       = local.initial_server_info["domain"]
  server_domain_zone       = local.zone
  server_add_eip           = false
  install_use_strategy     = local.install_method
  local_file_use_strategy  = local.download
  local_file_path          = local.initial_server_info["file_path"]
  install_rke2_version     = local.rke2_version
  install_rpm_channel      = "stable"
  install_remote_file_path = "${local.workfolder}/rke2"
  install_role             = "server"
  install_start            = true
  install_prep_script      = local.install_prep_script
  install_start_timeout    = 10
  config_use_strategy      = local.config_strat
  config_join_strategy     = "skip"
  config_default_name      = "50-default-config.yaml"
  config_supplied_content  = local.initial_server_info["config"]
  config_supplied_name     = "51-config.yaml"
  retrieve_kubeconfig      = true
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
  for_each = merge(local.cp_info, local.db_info, local.worker_info)
  triggers_replace = {
    initial_token = module.initial.join_token
    initial_url   = module.initial.join_url
  }
  provisioner "local-exec" {
    command = <<-EOT
      install -d ${each.value.path}
      cp ${abspath(path.module)}/*_prep.sh    ${each.value.path}
      cp ${abspath(path.module)}/*.yaml       ${each.value.path}
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
  for_each = merge(local.cp_info, local.db_info, local.worker_info)
  content = templatefile(
    "${abspath(path.module)}/main.tf.tftpl",
    {
      project_security_group_name = module.initial.project_security_group.name
      project_subnets             = jsonencode(module.initial.project_subnets)
      join_url                    = module.initial.join_url
      join_token                  = module.initial.join_token
      cluster_cidr                = jsonencode(module.initial.cluster_cidr)
      service_cidr                = jsonencode(module.initial.service_cidr)
      server_info                 = jsonencode(each.value)
      role                        = each.value.role
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
  for_each = merge(local.cp_info, local.db_info, local.worker_info)
  content  = <<-EOT
    key_name           = "${local.ssh_key_name}"
    key                = "${local.ssh_key}"
    identifier         = "${local.identifier}"
    owner              = "${local.owner}"
    project_name       = "${local.project_name}"
    username           = "${local.username}"
    domain             = "${local.domain}"
    zone               = "${local.zone}"
    rke2_version       = "${local.rke2_version}"
    os                 = "${local.image}"
    file_path          = "${each.value.file_path}"
    install_method     = "${local.install_method}"
    cni                = "${local.cni}"
    ip_family          = "${local.ip_family}"
    ingress_controller = "${local.ingress_controller}"
    runner_ip          = "${local.runner_ip}"
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
  for_each = merge(local.cp_info, local.db_info, local.worker_info)
  triggers_replace = {
    initial = module.initial.join_url
    info    = md5(jsonencode(merge(local.cp_info, local.db_info, local.worker_info)))
    path    = each.value.path
  }
  provisioner "local-exec" {
    command = <<-EOT
      cd ${self.triggers_replace.path}
      TF_DATA_DIR="${self.triggers_replace.path}"
      pwd
      ls -lah
      cat inputs.tfvars
      terraform init -upgrade=true
      terraform apply -var-file="inputs.tfvars" -auto-approve -state="${self.triggers_replace.path}/tfstate"
    EOT
  }
  provisioner "local-exec" {
    # warning! this is only triggered on destroy, not refresh/taint
    when    = destroy
    command = <<-EOT
      cd ${self.triggers_replace.path}
      TF_DATA_DIR="${self.triggers_replace.path}"
      pwd
      ls -lah
      env | grep TF_
      terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="${self.triggers_replace.path}/tfstate"
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
  content  = module.initial.kubeconfig
  filename = "${local.local_file_path}/kubeconfig"
}
