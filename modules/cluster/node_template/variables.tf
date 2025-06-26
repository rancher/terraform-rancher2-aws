variable "identifier" {
  type = string
}
variable "owner" {
  type = string
}
variable "acme_server_url" {
  type = string
}
variable "project_use_strategy" {
  type    = string
  default = "skip"
}
variable "project_name" {
  type    = string
  default = ""
}
variable "project_admin_cidrs" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded list.
  EOT
  default     = "[]"
}
variable "project_vpc_use_strategy" {
  type    = string
  default = "skip"
}
variable "project_vpc_name" {
  type    = string
  default = ""
}
variable "project_vpc_type" {
  type    = string
  default = "ipv4"
}
variable "project_vpc_zones" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded list.
  EOT
  default     = "[]"
}
variable "project_vpc_public" {
  type        = string
  description = <<-EOT
    If specified must be "true" or "false" only.
  EOT
  default     = "false"
}
variable "project_subnet_use_strategy" {
  type    = string
  default = "skip"
}
variable "project_subnet_names" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded list.
  EOT
  default     = "[]"
}
variable "project_security_group_use_strategy" {
  type    = string
  default = "skip"
}
variable "project_security_group_name" {
  type    = string
  default = ""
}
variable "project_security_group_type" {
  type    = string
  default = "project"
}
variable "project_load_balancer_use_strategy" {
  type    = string
  default = "skip"
}
variable "project_load_balancer_name" {
  type    = string
  default = ""
}
variable "project_load_balancer_access_cidrs" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded object.
    example:
    {
      test = {
        port        = 443
        ip_family   = "ipv4"
        cidrs       = ["1.1.1.1/32"]
        protocol    = "tcp"
        target_name = "test"
      }
    }
  EOT
  default     = null
}
variable "project_domain_use_strategy" {
  type    = string
  default = "skip"
}
variable "project_domain" {
  type    = string
  default = ""
}
variable "project_domain_zone" {
  type    = string
  default = ""
}
variable "project_domain_cert_use_strategy" {
  type    = string
  default = "skip"
}
variable "server_use_strategy" {
  type    = string
  default = "create"
}
variable "server_name" {
  type = string
}
variable "server_type" {
  type = string
}
variable "server_ip_family" {
  type = string
}
variable "server_private_ip" {
  type    = string
  default = ""
}
variable "server_availability_zone" {
  type    = string
  default = ""
}
variable "server_subnet_name" {
  type    = string
  default = ""
}
variable "server_security_group_name" {
  type    = string
  default = ""
}
variable "server_image_use_strategy" {
  type    = string
  default = "find"
}
variable "server_image_type" {
  type    = string
  default = "sle-micro-61"
}
variable "server_cloudinit_use_strategy" {
  type    = string
  default = "skip"
}
variable "server_cloudinit_content" {
  type    = string
  default = ""
}
variable "server_indirect_access_use_strategy" {
  type    = string
  default = "enable"
}
variable "server_load_balancer_target_groups" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded list.
  EOT
  default     = "[]"
}
variable "server_direct_access_use_strategy" {
  type    = string
  default = "ssh"
}
variable "server_access_addresses" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded object.
    Example:
    {
      workstation = {
        port      = 443,
        ip_family = "ipv4",
        cidrs     = ["100.1.1.1/32"],
        protocol  = "tcp"
      }
      ci = {
        port      = 443
        ip_family = "ipv4",
        cidrs     = ["50.1.1.1/32"],
        protocol  = "tcp"
      }
    }
  EOT
  default     = null
}
variable "server_user" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded object.
    Example:
    {
      user                     = "myuser"
      aws_keypair_use_strategy = "select"
      ssh_key_name             = "abc123"
      public_ssh_key           = "abc123 aabbccdd11223344"
      user_workfolder          = "/var/tmp"
      timeout                  = 10
    }
   EOT
  default     = null
}
variable "server_add_domain" {
  type    = string
  default = "false"
}
variable "server_domain_name" {
  type    = string
  default = ""
}
variable "server_domain_zone" {
  type    = string
  default = ""
}
variable "server_add_eip" {
  type    = string
  default = "false"
}
variable "install_use_strategy" {
  type    = string
  default = "rpm"
}
variable "local_file_use_strategy" {
  type    = string
  default = "download"
}
variable "local_file_path" {
  type    = string
  default = ""
}
variable "install_rke2_version" {
  type = string
}
variable "install_rpm_channel" {
  type    = string
  default = "stable"
}
variable "install_remote_file_path" {
  type    = string
  default = ""
}
variable "install_prep_script" {
  type        = string
  description = <<-EOT
    Base64 encoded string.
  EOT
  default     = ""
}
variable "install_start_prep_script" {
  type        = string
  description = <<-EOT
    Base64 encoded string.
  EOT
  default     = ""
}
variable "install_role" {
  type    = string
  default = "server"
}
variable "install_start" {
  type    = string
  default = "true"
}
variable "install_start_timeout" {
  type    = string
  default = "10"
}
variable "config_use_strategy" {
  type    = string
  default = "merge"
}
variable "config_default_name" {
  type    = string
  default = "50-default-config.yaml"
}
variable "config_supplied_content" {
  type        = string
  description = <<-EOT
    Base64 encoded string.
  EOT
  default     = ""
}
variable "config_supplied_name" {
  type    = string
  default = "51-rke2-config.yaml"
}
variable "config_join_strategy" {
  type    = string
  default = "skip"
}
variable "config_join_url" {
  type    = string
  default = ""
}
variable "config_join_token" {
  type    = string
  default = ""
}
variable "config_cluster_cidr" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded list.
  EOT
  default     = "[]"
}
variable "config_service_cidr" {
  type        = string
  description = <<-EOT
    Base64 encoded Json encoded list.
  EOT
  default     = "[]"
}
variable "retrieve_kubeconfig" {
  type        = string
  description = <<-EOT
    If specified, must be "true" or "false".
  EOT
  default     = "false"
}

