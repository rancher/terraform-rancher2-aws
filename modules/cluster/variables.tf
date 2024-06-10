variable "key_name" {
  type        = string
  description = "The name of an ssh key in AWS to use."
}
variable "key" {
  type        = string
  description = "The content of an ssh key for server access. The key must be loaded into the running ssh agent."
}

variable "identifier" {
  type        = string
  description = "A random alphanumeric string that is unique and less than 10 characters."
}

variable "zone" {
  type        = string
  description = "The dns zone to add domains under, must already exist in AWS Route53."
}

variable "rke2_version" {
  type        = string
  description = "The rke2 version to install."
}
variable "rpm_channel" {
  type        = string
  description = "The rpm channel to use when installing rke2, must be 'latest' or 'stable'."
  default     = "stable"
}
variable "os" {
  type        = string
  description = "The operating system to deploy."
  default     = "sle-micro-55" # BYOS = Bring Your Own Subscription, only use this if you have a subscription with SUSE or plan to get one directly rather than going through AWS
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
  description = "The ingress controller to use. Must be 'nginx' or 'traefik'."
  default     = "nginx"
}
variable "server_count" {
  type        = number
  description = "The number of control plane nodes to create."
  default     = 3
}
variable "agent_count" {
  type        = number
  description = "The number of worker nodes to create."
  default     = 3
}
