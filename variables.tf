variable "project_name" {
  type        = string
  description = <<-EOT
    A name for the project, used as a prefix for resource names.
  EOT
}
variable "project_domain" {
  type        = string
  description = <<-EOT
    The host for this project, should not include the zone.
    The zone for this domain must already exist in AWS and should be specified in the 'zone' variable.
    If left empty this will default to the project name.
  EOT
  default     = ""
}
variable "zone" {
  type        = string
  description = <<-EOT
    The Route53 DNS zone to deploy the cluster into.
    This is used to generate the DNS name for the cluster.
    The zone must already exist.
  EOT
}

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
variable "username" {
  type        = string
  description = <<-EOT
    The username to use for SSH access to the instance.
  EOT
}
variable "vpc_cidr" {
  type        = string
  description = <<-EOT
    An internal IP CIDR to use for the project.
  EOT
  default     = "10.0.0.0/16"
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
variable "local_file_path" {
  type        = string
  description = <<-EOT
    A local path to store files related to the install.
    Needs to an empty directory, isolated from the terraform files and state.
  EOT
  default     = "./rke2"
}
variable "workfolder" {
  type        = string
  description = <<-EOT
    The directory on the remote nodes which will be used for staging files and executing scripts.
  EOT
  default     = ""
}
variable "install_method" {
  type        = string
  description = <<-EOT
    The method to use for installing rke2 on the nodes.
    Can be either 'rpm' or 'tar'.
  EOT
}
variable "cni" {
  type        = string
  description = <<-EOT
    The CNI plugin to use for the cluster.
  EOT
}
variable "cluster_size" {
  type        = number
  description = <<-EOT
    The number of nodes to create.
    These will automatically be placed in different availability zones in the region.
    Make sure the region you are using has multiple availability zones to ensure high availability.
  EOT
  default     = 3
}
variable "admin_ip" {
  type        = string
  description = <<-EOT
    The IP address of the server running Terraform.
  EOT
}

variable "rancher_version" {
  type        = string
  description = <<-EOT
    The version of Rancher to install.
  EOT
  default     = "2.8.4"
}

variable "rancher_helm_repository" {
  type        = string
  description = <<-EOT
    The Helm repository to use for Rancher.
  EOT
  default     = "https://releases.rancher.com/server-charts/stable"
}

variable "cert_manager_version" {
  type        = string
  description = <<-EOT
    The version of cert-manager to install.
  EOT
  default     = "v1.11.0"
}
