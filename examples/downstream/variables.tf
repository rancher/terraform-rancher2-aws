# Variable format
# variable "" {
#   type        = string
#   description = <<-EOT
#   EOT
# }
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
    A unique identifier for the project, this helps when generating names for infrastructure items."
  EOT
}
variable "owner" {
  type        = string
  description = <<-EOT
    The owner of the project, this helps when generating names for infrastructure items."
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
  validation {
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+\\+rke2r\\d+$", var.rke2_version))
    error_message = "The rke2_version must match the format vX.Y.Z+rke2rN (eg. v1.34.7+rke2r1)."
  }
}
variable "rancher_version" {
  type        = string
  description = <<-EOT
    The version of rancher to install on the rke2 cluster.
  EOT
  default     = "2.14.1"
}
variable "file_path" {
  type        = string
  description = <<-EOT
    The path to the file containing the rke2 install script.
  EOT
  default     = "./rke2"
}
variable "data_dir" {
  type        = string
  description = <<-EOT
    The data directory for Terraform apply.
    This should be the relative path from path.root to TF_DATA_DIR.
    This should likely your TF_DATA_DIR environment variable.
    If this is left empty it will match path.root.
  EOT
  default     = ""
}
variable "acme_server_url" {
  type        = string
  description = <<-EOT
    The ACME server URL to use for cert-manager.
    This is useful for using the Let's Encrypt staging server for testing.
  EOT
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}
variable "runner_ip" {
  type        = string
  description = <<-EOT
    The IP of the sever running Terraform.
    Only this IP will have access to the cluster.
  EOT
  default     = ""
}
variable "aws_access_key_id" {
  type        = string
  description = <<-EOT
    AWS access key ID.
  EOT
  sensitive   = true
}
variable "aws_secret_access_key" {
  type        = string
  description = <<-EOT
    AWS secret key for EC2 services.
  EOT
  sensitive   = true
}
variable "aws_region" {
  type        = string
  description = <<-EOT
    AWS region EC2 services.
  EOT
  sensitive   = true
}
variable "aws_session_token" {
  type        = string
  description = <<-EOT
    AWS session token for EC2 services.
    If left empty the AWS provider will assume you are using permanent AWS credentials.
  EOT
  default     = ""
  sensitive   = true
}
variable "downstream_node_config" {
  type        = string
  description = <<-EOT
    This module defines four general cluster configurations: all-in-one-dev-node-config, all-in-one-ha-node-config, split-role-node-config, and prod-node-config.
    The all-in-one nodes have all roles (etcd, api, and worker).
    The dev node config has only one node.
    The split-role config has 3 control plane nodes and 3 worker nodes (it splits servers from agents).
    The "prod" config has 3 etcd, 3 api servers, and 3 worker nodes (it splits each kubernetes node role).
    The default is all-in-one-ha-node-config, which deploys a single all-in-one node downstream.
  EOT
  default     = "all-in-one-ha-node-config"
  validation {
    condition = (
      contains([
        "all-in-one-dev-node-config",
        "all-in-one-ha-node-config",
        "split-role-node-config",
        "prod-node-config",
      ], var.downstream_node_config)
    )
    error_message = "This must be one of the following: all-in-one-dev-node-config, all-in-one-ha-node-config, split-role-node-config, prod-node-config."
  }
}
