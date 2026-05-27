# Nodes are now deployed in a private subnet and do not have public IPs.
# Direct SSH access outputs have been removed.
output "cluster_data" {
  value = merge(data.rancher2_cluster.downstream, data.rancher2_cluster_v2.downstream)
}
