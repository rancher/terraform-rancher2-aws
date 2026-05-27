output "cluster_data" {
  value     = jsonencode(data.rancher2_cluster.local)
  sensitive = true
}
