# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  rancher_domain          = var.project_domain
  zone                    = var.zone
  zone_id                 = var.zone_id
  project_cert_name       = var.project_cert_name
  project_cert_key_id     = var.project_cert_key_id
  path                    = var.path
  cert_manager_version    = var.cert_manager_version
  configure_cert_manager  = var.configure_cert_manager
  cert_manager_configured = (local.configure_cert_manager ? "configured" : "unconfigured")
  cert_manager_path       = "${path.module}/${local.cert_manager_configured}"
  cert_manager_config     = var.cert_manager_configuration
  deploy_path             = "${local.path}/install_cert_manager"
}

module "deploy_cert_manager" {
  source = "../deploy"
  depends_on = [
  ]
  deploy_path = local.deploy_path
  data_path   = local.deploy_path
  template_files = [
    join("/", [local.cert_manager_path, "main.tf"]),
    join("/", [local.cert_manager_path, "variables.tf"]),
    join("/", [local.cert_manager_path, "versions.tf"]),
  ]
  skip_destroy = true # this is a one way operation, uninstall is not supported
  # if any of these change, redeploy/update
  deploy_trigger = md5(
    join("-", [
      local.rancher_domain,
      local.zone_id,
      local.project_cert_key_id,
      local.path,
      local.cert_manager_version,
      local.cert_manager_path,
      md5(jsonencode(local.cert_manager_config)),
      local.deploy_path,
    ])
  )
  environment_variables = {
    KUBE_CONFIG_PATH = "${abspath(local.path)}/kubeconfig"
    KUBECONFIG       = "${abspath(local.path)}/kubeconfig"
  }
  inputs = <<-EOT
    cert_manager_version       = "${local.cert_manager_version}"
    project_cert_name          = "${local.project_cert_name}"
    project_cert_key_id        = "${local.project_cert_key_id}"
    project_domain             = "${local.rancher_domain}"
    zone                       = "${local.zone}"
    zone_id                    = "${local.zone_id}"
    cert_manager_configuration = {
      aws_region            = "${local.cert_manager_config.aws_region}"
      aws_session_token     = "${local.cert_manager_config.aws_session_token}"
      aws_access_key_id     = "${local.cert_manager_config.aws_access_key_id}"
      aws_secret_access_key = "${local.cert_manager_config.aws_secret_access_key}"
    }
  EOT
}
