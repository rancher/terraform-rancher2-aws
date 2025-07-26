
variable "vpc_id" {
  type        = string
  description = <<-EOT
    The id of the VPC that the Rancher cluster belongs to.
  EOT
}
variable "name" {
  type        = string
  description = <<-EOT
    The name to give the security group.
  EOT
}
variable "load_balancer_security_group_id" {
  type        = string
  description = <<-EOT
    The load balancer's security group id.
  EOT
}
variable "rancher_security_group_id" {
  type        = string
  description = <<-EOT
    Rancher's security group id.
  EOT
}
