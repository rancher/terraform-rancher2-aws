output "name" {
  value = local.name
}
output "id" {
  value = aws_security_group.downstream_cluster.id
}
