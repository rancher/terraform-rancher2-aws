locals {
  node_count    = var.node_count
  node_id       = var.node_id
  max_wait      = var.max_wait
  wait_duration = (local.max_wait / 4)
  wait_1        = local.wait_duration * (length(data.aws_instances.rke2_instance_nodes_1.public_ips) == local.node_count ? 0 : 1)
  wait_2        = local.wait_duration * (length(data.aws_instances.rke2_instance_nodes_2.public_ips) == local.node_count ? 0 : 1)
  wait_3        = local.wait_duration * (length(data.aws_instances.rke2_instance_nodes_3.public_ips) == local.node_count ? 0 : 1)
  wait_4        = local.wait_duration * (length(data.aws_instances.rke2_instance_nodes_4.public_ips) == local.node_count ? 0 : 1)
  node_ips      = { for i in range(local.node_count) : tostring(i) => data.aws_instances.rke2_instance_nodes_4.public_ips[i] }
}

# each instance of this module will run simultaneously,
#  so we need the duration of the wait to increase with each iteration so that they become effectively parallel
# only the last iteration will be the one that counts
data "aws_instances" "rke2_instance_nodes_1" {
  filter {
    name   = "tag:NodeID"
    values = [local.node_id]
  }
}
resource "time_sleep" "wait_for_nodes_1" {
  depends_on = [
    data.aws_instances.rke2_instance_nodes_1,
  ]
  create_duration = "${local.wait_1}s"
}


data "aws_instances" "rke2_instance_nodes_2" {
  depends_on = [
    data.aws_instances.rke2_instance_nodes_1,
    time_sleep.wait_for_nodes_1,
  ]
  filter {
    name   = "tag:NodeID"
    values = [local.node_id]
  }
}
resource "time_sleep" "wait_for_nodes_2" {
  depends_on = [
    data.aws_instances.rke2_instance_nodes_1,
    time_sleep.wait_for_nodes_1,
    data.aws_instances.rke2_instance_nodes_2,
  ]
  create_duration = "${local.wait_2}s"
}


data "aws_instances" "rke2_instance_nodes_3" {
  depends_on = [
    data.aws_instances.rke2_instance_nodes_1,
    time_sleep.wait_for_nodes_1,
    data.aws_instances.rke2_instance_nodes_2,
    time_sleep.wait_for_nodes_2,
  ]
  filter {
    name   = "tag:NodeID"
    values = [local.node_id]
  }
}
resource "time_sleep" "wait_for_nodes_3" {
  depends_on = [
    data.aws_instances.rke2_instance_nodes_1,
    time_sleep.wait_for_nodes_1,
    data.aws_instances.rke2_instance_nodes_2,
    time_sleep.wait_for_nodes_2,
    data.aws_instances.rke2_instance_nodes_3,
  ]
  create_duration = "${local.wait_3}s"
}


data "aws_instances" "rke2_instance_nodes_4" {
  depends_on = [
    data.aws_instances.rke2_instance_nodes_1,
    time_sleep.wait_for_nodes_1,
    data.aws_instances.rke2_instance_nodes_2,
    time_sleep.wait_for_nodes_2,
    data.aws_instances.rke2_instance_nodes_3,
    time_sleep.wait_for_nodes_3,
  ]
  filter {
    name   = "tag:NodeID"
    values = [local.node_id]
  }
}
resource "time_sleep" "wait_for_nodes_4" {
  depends_on = [
    data.aws_instances.rke2_instance_nodes_1,
    time_sleep.wait_for_nodes_1,
    data.aws_instances.rke2_instance_nodes_2,
    time_sleep.wait_for_nodes_2,
    data.aws_instances.rke2_instance_nodes_3,
    time_sleep.wait_for_nodes_3,
    data.aws_instances.rke2_instance_nodes_4,
  ]
  create_duration = "${local.wait_4}s"
}
