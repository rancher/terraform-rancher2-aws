variable "node_id" {
  type        = string
  description = <<-EOT
    The id that the nodes are tagged with so that we can find them.
    The value of the 'NodeID' tag.
  EOT
}
variable "node_count" {
  type        = number
  description = <<-EOT
    The number of nodes to look for.
  EOT
}
variable "max_wait" {
  type        = number
  description = <<-EOT
    The maximum number of seconds to wait for the nodes to be ready.
    The module will check 4 times throughout the duration and if it finds the nodes it will stop.
    Defaults to 20 minutes.
  EOT
  default     = 1200 # 20 minutes
}
