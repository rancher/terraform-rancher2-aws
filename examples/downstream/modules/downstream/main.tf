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
  node_info       = var.node_info
  node_count      = sum([for i in range(length(local.node_info)) : local.node_info[keys(local.node_info)[i]].quantity])
  node_id         = "${local.cluster_name}-nodes"
  runner_ip       = (var.direct_node_access != null ? var.direct_node_access.runner_ip : "10.1.1.1") # the IP running Terraform
  ssh_access_key  = (var.direct_node_access != null ? var.direct_node_access.ssh_access_key : "fake123abc")
  ssh_access_user = (var.direct_node_access != null ? var.direct_node_access.ssh_access_user : "fake")
  # rke2 info
  rke2_version             = var.rke2_version
  rke2_ingress_config_name = "rke2-ingress-config"
  rke2_ingress_config_key  = "config"
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
    tags           = join(",", ["Id", local.identifier, "Owner", local.owner, "NodeID", local.node_id])
    ssh_user       = each.value.ami_ssh_user
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
# resource "terraform_data" "cluster_destroy_helpers" {
#   depends_on = [
#     rancher2_machine_config_v2.nodes,
#     terraform_data.patch_machine_configs,
#   ]
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<-EOT
#       # here should be the removal of finalizers for the cluster objects
#     EOT
#   }
# }
resource "terraform_data" "ingress_config" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
  ]
  provisioner "local-exec" {
    # https://ranchermanager.docs.rancher.com/reference-guides/cluster-configuration/rancher-server-configuration/rke2-cluster-configuration#machineselectorfiles
    command = <<-EOT
      ${path.module}/applyK8sManifest.sh <<EOF
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: "${local.rke2_ingress_config_name}"
        namespace: "fleet-default"
        annotations:
          rke.cattle.io/object-authorized-for-clusters: ${local.cluster_name}
      data:
        "${local.rke2_ingress_config_key}": "ingress-controller: traefik"
      EOF
    EOT
  }
}
resource "rancher2_cluster_v2" "rke2_cluster" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    # terraform_data.cluster_destroy_helpers,
    terraform_data.ingress_config,
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
    machine_selector_files {
      machine_label_selector {
        match_expressions {}
        match_labels = {}
      }
      file_sources {
        configmap {
          name = local.rke2_ingress_config_name
          items {
            key  = local.rke2_ingress_config_key
            path = "/etc/rancher/rke2/config.yaml.d/51-rke2-ingress-traefik.yaml"
          }
        }
      }
    }
  }
  timeouts {
    create = "120m"
  }
}

module "get_instances" {
  source = "../get_instances"
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    # terraform_data.cluster_destroy_helpers,
    terraform_data.ingress_config,
  ]
  node_id    = local.node_id
  node_count = local.node_count
  max_wait   = 1200 # 20 minutes
}

# this allows the load balancer to accept connections initiated by the downstream cluster's public ip addresses
# this weird in-flight grab of the nodes and manipulating the security groups is not good,
#  but the only way to allow ingress when the downstream cluster has public IPs
# FYI: security group references only work with private IPs
resource "aws_vpc_security_group_ingress_rule" "downstream_public_ingress_loadbalancer" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    # terraform_data.cluster_destroy_helpers,
    terraform_data.ingress_config,
    module.get_instances,
  ]
  for_each          = module.get_instances.node_ips
  security_group_id = local.load_balancer_security_group_id
  ip_protocol       = "-1"
  cidr_ipv4         = "${each.value}/32"
}

# this allows the runner to access the downstream cluster's nodes
resource "aws_vpc_security_group_ingress_rule" "downstream_public_ingress_runner" {
  depends_on = [
    rancher2_machine_config_v2.nodes,
    terraform_data.patch_machine_configs,
    # terraform_data.cluster_destroy_helpers,
    terraform_data.ingress_config,
    module.get_instances,
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
    # terraform_data.cluster_destroy_helpers,
    terraform_data.ingress_config,
    rancher2_cluster_v2.rke2_cluster,
    module.get_instances,
    aws_vpc_security_group_ingress_rule.downstream_public_ingress_loadbalancer,
    aws_vpc_security_group_ingress_rule.downstream_public_ingress_runner,
  ]
  cluster_id = rancher2_cluster_v2.rke2_cluster.cluster_v1_id
}
