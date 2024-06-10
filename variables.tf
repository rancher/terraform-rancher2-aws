variable "key_name" {
  type        = string
  description = <<-EOT
    The name of an AWS key pair to use for SSH access to the instance.
    This key should already be added to your ssh agent for server authentication.
  EOT
}
variable "key" {
  type        = string
  description = <<-EOT
    The contents of an AWS key pair to use for SSH access to the instance.
    This is necessary for installing rke2 on the nodes and will be removed after installation.
  EOT
}
variable "identifier" {
  type        = string
  description = <<-EOT
    A unique identifier for the project, this helps when generating names for infrastrucutre items."
  EOT
}
variable "zone" {
  type        = string
  description = <<-EOT
    The Route53 DNS zone to deploy the cluster into.
    This is used to generate the DNS name for the cluster.
    The zone must already exist.
  EOT
}
variable "rke2_version" {
  type        = string
  description = <<-EOT
    The version of rke2 to install on the nodes.
  EOT
}
variable "os" {
  type        = string
  description = <<-EOT
    The operating system to use for the nodes.
  EOT
}
variable "file_path" {
  type        = string
  description = <<-EOT
    The path to the file containing the rke2 install script.
  EOT
}
variable "install_method" {
  type        = string
  description = <<-EOT
    The method to use for installing rke2 on the nodes.
    Can be either 'rpm' or 'tar'.
  EOT
}
