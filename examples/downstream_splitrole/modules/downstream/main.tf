locals {
  # general
  identifier   = var.identifier
  owner        = var.owner
  cluster_name = var.name
  # aws access
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  aws_session_token     = var.aws_session_token
  aws_region            = var.aws_region
  aws_region_letter     = var.aws_region_letter
  # networking info
  vpc_id                          = var.vpc_id
  subnet_id                       = var.subnet_id
  downstream_security_group_id    = var.downstream_security_group_id
  downstream_security_group_name  = var.downstream_security_group_name
  load_balancer_security_group_id = var.load_balancer_security_group_id
  # node info
  node_info  = var.node_info
  node_count = sum([for i in range(length(local.node_info)) : local.node_info[keys(local.node_info)[i]].quantity])
  # if the IPs aren't found, then this should fail
  node_ips        = { for i in range(local.node_count) : tostring(i) => data.aws_instances.rke2_instance_nodes.public_ips[i] }
  node_id         = "${local.cluster_name}-nodes"
  node_wait_time  = "${tostring(local.node_count * 60)}s"                                            # 60 seconds per node
  runner_ip       = (var.direct_node_access != null ? var.direct_node_access.runner_ip : "10.1.1.1") # the IP running Terraform
  ssh_access_key  = (var.direct_node_access != null ? var.direct_node_access.ssh_access_key : "fake123abc")
  ssh_access_user = (var.direct_node_access != null ? var.direct_node_access.ssh_access_user : "fake")
  # rke2 info
  rke2_version = var.rke2_version
}

resource "rancher2_machine_config_v2" "nodes" {
  for_each      = local.node_info
  generate_name = "${each.key}-${local.cluster_name}"
  amazonec2_config {
    ami            = each.value.aws_ami_id
    region         = local.aws_region
    security_group = [local.downstream_security_group_name]
    subnet_id      = local.subnet_id
    vpc_id         = local.vpc_id
    zone           = local.aws_region_letter
    session_token  = local.aws_session_token
    instance_type  = each.value.aws_instance_type
    ssh_user       = each.value.ami_ssh_user
    tags           = join(",", ["Id", local.identifier, "Owner", local.owner, "NodeId", local.node_id])
    userdata       = <<-EOT
      #cloud-config

      merge_how:
       - name: list
         settings: [replace]
       - name: dict
         settings: [replace]

      users:
        - name: ${local.ssh_access_user}
          gecos: ${local.ssh_access_user}
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: users, ${each.value.ami_admin_group}
          lock_passwd: true
          ssh_authorized_keys:
            - ${local.ssh_access_key}
          homedir: /home/${local.ssh_access_user}
    EOT
  }
}

resource "terraform_data" "patch_machine_configs" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
  ]
  triggers_replace = {
    node_config    = local.node_info
    aws_access_key = local.aws_access_key_id
    aws_secret_key = local.aws_secret_access_key
  }
  provisioner "local-exec" {
    command = <<-EOT
      # WARNING! This will update all machine configs in the fleet-default namespace.
      ${path.module}/addKeyToAmazonConfig.sh "${local.aws_access_key_id}" "${local.aws_secret_access_key}"
    EOT
  }
}

resource "rancher2_cluster_v2" "rke2_cluster" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
  ]
  name                  = local.cluster_name
  kubernetes_version    = local.rke2_version
  enable_network_policy = true
  rke_config {
    dynamic "machine_pools" {
      for_each = local.node_info
      content {
        name               = "${local.cluster_name}-${machine_pools.key}"
        control_plane_role = machine_pools.value["control_plane_role"]
        etcd_role          = machine_pools.value["etcd_role"]
        worker_role        = machine_pools.value["worker_role"]
        quantity           = machine_pools.value["quantity"]

        dynamic "machine_config" {
          for_each = toset([machine_pools.key])
          content {
            kind = rancher2_machine_config_v2.nodes[machine_config.key].kind
            name = rancher2_machine_config_v2.nodes[machine_config.key].name
          }
        }
      }
    }
  }
  timeouts {
    create = "120m"
  }
}

resource "time_sleep" "wait_for_nodes" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
  ]
  create_duration = local.node_wait_time
}

data "aws_instances" "rke2_instance_nodes" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    time_sleep.wait_for_nodes,
  ]
  filter {
    name   = "tag:NodeId"
    values = [local.node_id]
  }
}

# this allows the load balancer to accept connections initiated by the downstream cluster's public ip addresses
# this weird in-flight grab of the nodes and manipulating the security groups is not good,
#  but the only way to allow ingress when the downstream cluster has public IPs
# FYI: security group references only work with private IPs
resource "aws_vpc_security_group_ingress_rule" "downstream_public_ingress_loadbalancer" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    time_sleep.wait_for_nodes,
    data.aws_instances.rke2_instance_nodes,
  ]
  for_each          = local.node_ips
  security_group_id = local.load_balancer_security_group_id
  ip_protocol       = "-1"
  cidr_ipv4         = "${each.value}/32"
}

resource "aws_vpc_security_group_ingress_rule" "downstream_public_ingress_runner" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    time_sleep.wait_for_nodes,
    data.aws_instances.rke2_instance_nodes,
  ]
  security_group_id = local.downstream_security_group_id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.runner_ip}/32"
}

resource "rancher2_cluster_sync" "sync" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    rancher2_cluster_v2.rke2_cluster,
    time_sleep.wait_for_nodes,
    data.aws_instances.rke2_instance_nodes,
    aws_vpc_security_group_ingress_rule.downstream_public_ingress_loadbalancer,
    aws_vpc_security_group_ingress_rule.downstream_public_ingress_runner,
  ]
  cluster_id = rancher2_cluster_v2.rke2_cluster.cluster_v1_id
}
