variable "key_name" {
  type        = string
  description = "The name of an ssh key that already exists in AWS of that you want to create."
}
variable "key" {
  type        = string
  description = "The content of an ssh key for server access. The key must be loaded into the running ssh agent."
}
variable "identifier" {
  type        = string
  description = "A random alphanumeric string that is unique and less than 10 characters."
}
variable "owner" {
  type        = string
  description = <<-EOT
    An identifier for the person or group responsible for the resources created.
    A tag 'Owner' will be added to the servers with this value.
  EOT
}
variable "project_name" {
  type        = string
  description = "The name for the project, resources will be given a tag 'Name' with this value as a prefix."
}
variable "username" {
  type        = string
  description = <<-EOT
    The username to add to the server for Terraform to configure it.
    This user will have passwordless sudo, but login only from the 'runner_ip' address
    and only with the appropriate key (which must be in your ssh agent).
  EOT
}
variable "domain" {
  type        = string
  description = <<-EOT
    The dns domain for the project, the zone must already exist in AWS Route53.
    Example: test.example.com where example.com is a zone that is already available.
  EOT
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
  default     = "sle-micro-60"
}
variable "size" {
  type        = string
  description = <<-EOT
    The size of the Rancher cluster to create.
    As guided by https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements#rke2-kubernetes.
    Options are: small, medium, or large
    We will select the appropriate server sizes for the different roles based on this input.
  EOT
  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = "The size value must be one of small, medium, or large."
  }
  default = "small"
}
variable "file_path" {
  type        = string
  description = "The local file path to stage or retrieve files."
  default     = ""
}
variable "install_method" {
  type        = string
  description = "The method used to install RKE2 on the nodes. Must be either 'tar' or 'rpm'."
  default     = "tar"
}
variable "cni" {
  type        = string
  description = "Which CNI configuration file to add."
  default     = "canal"
}
variable "ip_family" {
  type        = string
  description = "The IP family to use. Must be 'ipv4', 'ipv6', or 'dualstack'."
  default     = "ipv4"
}
variable "ingress_controller" {
  type        = string
  description = "The ingress controller to use. Must be 'nginx' or 'traefik'. Currently only supports 'nginx'."
  default     = "nginx"
}
variable "runner_ip" {
  type        = string
  description = "The IP address of the computer running terraform."
}
variable "api_nodes" {
  type        = number
  description = "The number of API server nodes to deploy, should be at least 3 for high availability."
  default     = 3
}
variable "database_nodes" {
  type        = number
  description = "The number of database nodes to deploy, should be at least 3 for high availability."
  default     = 3
}
variable "worker_nodes" {
  type        = number
  description = "The number of worker nodes to deploy, should be at least 3 for high availability."
  default     = 3
}
