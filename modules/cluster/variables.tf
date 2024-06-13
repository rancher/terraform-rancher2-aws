variable "project_name" {
  type        = string
  description = "A name for the project, used to create a unique name for resources."
}
variable "key_name" {
  type        = string
  description = "The name of an ssh key that already exists in AWS of that you want to create."
}
variable "key" {
  type        = string
  description = "The content of an ssh key for server access. The key must be loaded into the running ssh agent."
}
variable "username" {
  type        = string
  description = "The username to use for ssh access to the server."
}
variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
}
variable "zone" {
  type        = string
  description = "The dns zone to add domains under, must already exist in AWS Route53."
}
variable "rke2_version" {
  type        = string
  description = "The rke2 version to install."
}
variable "os" {
  type        = string
  description = "The operating system to deploy."
}
variable "local_file_path" {
  type        = string
  description = "The local file path to stage or retrieve files."
}
variable "workfolder" {
  type        = string
  description = "The remote path to stage or retrieve files and run config scripts."
}
variable "install_method" {
  type        = string
  description = "The method used to install RKE2 on the nodes. Must be either 'tar' or 'rpm'."
}
variable "cni" {
  type        = string
  description = "Which CNI configuration file to add."
}
variable "cluster_size" {
  type        = number
  description = "The number of nodes to create."
}
variable "admin_ip" {
  type        = string
  description = "The IP address for the server running Terraform."
}
