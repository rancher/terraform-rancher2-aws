# project
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
# access
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
  description = <<-EOT
    The username to add to the server for Terraform to configure it.
    This user will have passwordless sudo, but login only from the 'runner_ip' address
    and only with the appropriate key (which must be in your ssh agent).
  EOT
}
variable "runner_ip" {
  type        = string
  description = "The IP address of the computer running terraform."
}
# rke2
variable "rke2_version" {
  type        = string
  description = "The rke2 version to install."
}
variable "file_path" {
  type        = string
  description = "The local file path to stage or retrieve files."
}
variable "install_method" {
  type        = string
  description = "The method used to install RKE2 on the nodes. Must be either 'tar' or 'rpm'."
}
variable "cni" {
  type        = string
  description = "Which CNI configuration file to add."
}
variable "node_configuration" {
  type = map(object({
    type            = string
    size            = string
    os              = string
    indirect_access = bool
    initial         = bool
  }))
  description = <<-EOT
    A map of configuration options for the nodes to constitute the cluster.
    Only one node should have the "initial" attribute set to true.
    Be careful which node you decide to start the cluster,
      it must host the database for others to be able to join properly.
    There are 5 types of node: 'all-in-one', 'control-plane', 'worker', 'database', 'api'.
      'all-in-one' nodes have all roles (control-plane, worker, etcd)
      'control-plane' nodes have the api (control-plane) and database (etcd) roles
      'worker' nodes have just the 'worker' role
      'database' nodes have only the database (etcd) role
      'api' nodes have only the api (control-plane) server role
    By default we will set taints to prevent non-component workloads
      from running on database, api, and control-plane nodes.
    Size correlates to the server size options from the server module:
      https://github.com/rancher/terraform-aws-server/blob/main/modules/server/types.tf
    We recommend using the size nodes that best fit your use case:
      https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements#rke2-kubernetes
    OS correlates to the server image options from the server module:
      https://github.com/rancher/terraform-aws-server/blob/main/modules/image/types.tf
    We recommend using the same os for all servers, we don't currently test for clusters with mixed OS types.
    Indirect access refers to how the cluster will be load balanced,
      some admins are ok with every server in the cluster responding to inbound requests since the built in proxy will redirect,
      but that isn't always the best choice since some nodes (like database nodes and secure workers)
      are better to restrict to internal access only.
      Setting this value to true will allow the network load balancer to direct traffic to the node.
      Setting this value to false will prevent the load balancer from directing traffic to the node.
  EOT
  default = {
    "initial" = {
      type            = "all-in-one"
      size            = "medium"
      os              = "sle-micro-60"
      indirect_access = true
      initial         = true
    }
  }
}
variable "ip_family" {
  type        = string
  description = "The IP family to use. Must be 'ipv4', 'ipv6', or 'dualstack'."
}
# variable "ingress_controller" {
#   type        = string
#   description = "The ingress controller to use. Must be 'nginx' or 'traefik'. Currently only supports 'nginx'."
# }
variable "skip_cert_creation" {
  type        = bool
  description = "Skip the generation of a certificate, useful when configuring cert manager."
  default     = false
}
variable "acme_server_url" {
  type        = string
  description = "Server URL to make ACME requests to."
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}
