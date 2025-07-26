provider "aws" {
  default_tags {
    tags = {
      Id    = local.identifier
      Owner = local.owner
    }
  }
}

provider "acme" {
  server_url = local.acme_server_url
}

locals {
  identifier                          = var.identifier
  owner                               = var.owner
  acme_server_url                     = var.acme_server_url
  project_use_strategy                = var.project_use_strategy
  project_name                        = var.project_name
  project_admin_cidrs                 = (var.project_admin_cidrs != "[]" ? jsondecode(base64decode(var.project_admin_cidrs)) : [])
  project_vpc_use_strategy            = var.project_vpc_use_strategy
  project_vpc_name                    = var.project_vpc_name
  project_vpc_type                    = var.project_vpc_type
  project_vpc_zones                   = (var.project_vpc_zones != "[]" ? jsondecode(base64decode(var.project_vpc_zones)) : [])
  project_vpc_public                  = (var.project_vpc_public == "true" ? true : false)
  project_subnet_use_strategy         = var.project_subnet_use_strategy
  project_subnet_names                = (var.project_subnet_names != "[]" ? jsondecode(base64decode(var.project_subnet_names)) : []) # list
  project_security_group_use_strategy = var.project_security_group_use_strategy
  project_security_group_name         = var.project_security_group_name
  project_security_group_type         = var.project_security_group_type
  project_load_balancer_use_strategy  = var.project_load_balancer_use_strategy
  project_load_balancer_name          = var.project_load_balancer_name
  project_load_balancer_access_cidrs  = (var.project_load_balancer_access_cidrs != null ? jsondecode(base64decode(var.project_load_balancer_access_cidrs)) : null) # object
  project_domain_use_strategy         = var.project_domain_use_strategy
  project_domain                      = var.project_domain
  project_domain_zone                 = var.project_domain_zone
  project_domain_cert_use_strategy    = var.project_domain_cert_use_strategy
  server_use_strategy                 = var.server_use_strategy
  server_name                         = var.server_name
  server_type                         = var.server_type
  server_ip_family                    = var.server_ip_family
  server_private_ip                   = var.server_private_ip
  server_availability_zone            = var.server_availability_zone
  server_subnet_name                  = var.server_subnet_name
  server_security_group_name          = var.server_security_group_name
  server_image_use_strategy           = var.server_image_use_strategy
  server_image_type                   = var.server_image_type
  server_cloudinit_use_strategy       = var.server_cloudinit_use_strategy
  server_cloudinit_content            = var.server_cloudinit_content
  server_indirect_access_use_strategy = var.server_indirect_access_use_strategy
  server_load_balancer_target_groups  = (var.server_load_balancer_target_groups != "[]" ? jsondecode(base64decode(var.server_load_balancer_target_groups)) : []) # list
  server_direct_access_use_strategy   = var.server_direct_access_use_strategy
  server_access_addresses             = (var.server_access_addresses != null ? jsondecode(base64decode(var.server_access_addresses)) : null) # object
  server_user                         = (var.server_user != null ? jsondecode(base64decode(var.server_user)) : null)                         # object
  server_add_domain                   = var.server_add_domain
  server_domain_name                  = var.server_domain_name
  server_domain_zone                  = var.server_domain_zone
  server_add_eip                      = var.server_add_eip
  install_use_strategy                = var.install_use_strategy
  local_file_use_strategy             = var.local_file_use_strategy
  local_file_path                     = var.local_file_path
  install_rke2_version                = var.install_rke2_version
  install_rpm_channel                 = var.install_rpm_channel
  install_remote_file_path            = var.install_remote_file_path
  install_prep_script                 = (var.install_prep_script != "" ? base64decode(var.install_prep_script) : "")
  install_start_prep_script           = (var.install_start_prep_script != "" ? base64decode(var.install_start_prep_script) : "")
  install_role                        = var.install_role
  install_start                       = var.install_start
  install_start_timeout               = var.install_start_timeout
  config_use_strategy                 = var.config_use_strategy
  config_default_name                 = var.config_default_name
  config_supplied_content             = (var.config_supplied_content != "" ? base64decode(var.config_supplied_content) : "")
  config_supplied_name                = var.config_supplied_name
  config_join_strategy                = var.config_join_strategy
  config_join_url                     = var.config_join_url
  config_join_token                   = var.config_join_token
  config_cluster_cidr                 = (var.config_cluster_cidr != "[]" ? jsondecode(base64decode(var.config_cluster_cidr)) : []) # list
  config_service_cidr                 = (var.config_service_cidr != "[]" ? jsondecode(base64decode(var.config_service_cidr)) : []) # list
  retrieve_kubeconfig                 = (var.retrieve_kubeconfig == "true" ? true : false)                                         # bool
}

module "node" {
  source                              = "rancher/rke2/aws"
  version                             = "2.0.0"
  project_use_strategy                = local.project_use_strategy
  project_name                        = local.project_name
  project_admin_cidrs                 = local.project_admin_cidrs
  project_vpc_use_strategy            = local.project_vpc_use_strategy
  project_vpc_name                    = local.project_vpc_name
  project_vpc_type                    = local.project_vpc_type
  project_vpc_zones                   = local.project_vpc_zones
  project_vpc_public                  = local.project_vpc_public
  project_subnet_use_strategy         = local.project_subnet_use_strategy
  project_subnet_names                = local.project_subnet_names
  project_security_group_use_strategy = local.project_security_group_use_strategy
  project_security_group_name         = local.project_security_group_name
  project_security_group_type         = local.project_security_group_type
  project_load_balancer_use_strategy  = local.project_load_balancer_use_strategy
  project_load_balancer_name          = local.project_load_balancer_name
  project_load_balancer_access_cidrs  = local.project_load_balancer_access_cidrs
  project_domain_use_strategy         = local.project_domain_use_strategy
  project_domain                      = local.project_domain
  project_domain_zone                 = local.project_domain_zone
  project_domain_cert_use_strategy    = local.project_domain_cert_use_strategy
  server_use_strategy                 = local.server_use_strategy
  server_name                         = local.server_name
  server_type                         = local.server_type
  server_ip_family                    = local.server_ip_family
  server_private_ip                   = local.server_private_ip
  server_availability_zone            = local.server_availability_zone
  server_subnet_name                  = local.server_subnet_name
  server_security_group_name          = local.server_security_group_name # should always match project security group
  server_image_use_strategy           = local.server_image_use_strategy
  server_image_type                   = local.server_image_type
  server_cloudinit_use_strategy       = local.server_cloudinit_use_strategy
  server_cloudinit_content            = local.server_cloudinit_content
  server_indirect_access_use_strategy = local.server_indirect_access_use_strategy
  server_load_balancer_target_groups  = local.server_load_balancer_target_groups
  server_direct_access_use_strategy   = local.server_direct_access_use_strategy
  server_access_addresses             = local.server_access_addresses
  server_user                         = local.server_user
  server_add_domain                   = local.server_add_domain
  server_domain_name                  = local.server_domain_name
  server_domain_zone                  = local.server_domain_zone
  server_add_eip                      = local.server_add_eip
  install_use_strategy                = local.install_use_strategy
  local_file_use_strategy             = local.local_file_use_strategy
  local_file_path                     = local.local_file_path
  install_rke2_version                = local.install_rke2_version
  install_rpm_channel                 = local.install_rpm_channel
  install_remote_file_path            = local.install_remote_file_path
  install_prep_script                 = local.install_prep_script
  install_start_prep_script           = local.install_start_prep_script
  install_role                        = local.install_role
  install_start                       = local.install_start
  install_start_timeout               = local.install_start_timeout
  config_use_strategy                 = local.config_use_strategy
  config_default_name                 = local.config_default_name
  config_supplied_content             = local.config_supplied_content
  config_supplied_name                = local.config_supplied_name
  config_join_strategy                = local.config_join_strategy
  config_join_url                     = local.config_join_url
  config_join_token                   = local.config_join_token
  config_cluster_cidr                 = local.config_cluster_cidr
  config_service_cidr                 = local.config_service_cidr
  retrieve_kubeconfig                 = local.retrieve_kubeconfig
}

