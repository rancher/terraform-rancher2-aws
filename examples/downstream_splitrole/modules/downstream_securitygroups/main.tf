locals {
  vpc_id                          = var.vpc_id
  name                            = var.name
  security_group_id               = var.rancher_security_group_id
  load_balancer_security_group_id = var.load_balancer_security_group_id
}

resource "aws_security_group" "downstream_cluster" {
  description = "Access to downstream cluster"
  name        = local.name
  vpc_id      = local.vpc_id
  tags = {
    Name = local.name
  }
  lifecycle {
    ignore_changes = [
      ingress,
      egress,
    ]
  }
}
# this allows servers attached to the project security group to accept connections initiated by the downstream cluster
resource "aws_vpc_security_group_ingress_rule" "downstream_ingress_rancher" {
  depends_on = [
    aws_security_group.downstream_cluster,
  ]
  referenced_security_group_id = aws_security_group.downstream_cluster.id
  security_group_id            = local.security_group_id
  ip_protocol                  = "-1"
}
# this allows the load balancer to accept connections initiated by the downstream cluster
resource "aws_vpc_security_group_ingress_rule" "downstream_ingress_loadbalancer" {
  depends_on = [
    aws_security_group.downstream_cluster,
  ]
  referenced_security_group_id = aws_security_group.downstream_cluster.id
  security_group_id            = local.load_balancer_security_group_id
  ip_protocol                  = "-1"
}

# this allows the downstream cluster to reach out to any public ipv4 address
resource "aws_vpc_security_group_egress_rule" "downstream_egress_ipv4" {
  depends_on = [
    aws_security_group.downstream_cluster,
  ]
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.downstream_cluster.id
}
# this allows the downstream cluster to reach out to any public ipv6 address
resource "aws_vpc_security_group_egress_rule" "downstream_egress_ipv6" {
  depends_on = [
    aws_security_group.downstream_cluster,
  ]
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
  security_group_id = aws_security_group.downstream_cluster.id
}
# this allows the downstream cluster to reach out to any server attached to the project security group
resource "aws_vpc_security_group_egress_rule" "downstream_egress_project_link" {
  depends_on = [
    aws_security_group.downstream_cluster,
  ]
  referenced_security_group_id = local.security_group_id
  security_group_id            = aws_security_group.downstream_cluster.id
  ip_protocol                  = "-1"
}
# this allows nodes to talk to each other
resource "aws_vpc_security_group_ingress_rule" "downstream_ingress_internal_ipv4" {
  depends_on = [
    aws_security_group.downstream_cluster,
  ]
  ip_protocol       = "-1"
  cidr_ipv4         = "10.0.0.0/16"
  security_group_id = aws_security_group.downstream_cluster.id
}
