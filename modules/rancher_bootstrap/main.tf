# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  project_domain                  = var.project_domain
  zone_id                         = var.zone_id
  region                          = var.region
  email                           = var.email
  acme_server_url                 = var.acme_server_url
  rancher_version                 = replace(var.rancher_version, "v", "") # don't include the v
  rancher_helm_repo               = var.rancher_helm_repo
  rancher_helm_channel            = var.rancher_helm_channel
  cert_manager_version            = var.cert_manager_version
  path                            = var.path
  externalTLS                     = var.externalTLS
  rancher_path                    = (local.externalTLS ? "${path.module}/rancher_externalTLS" : "${path.module}/rancher")
  deploy_path                     = "${local.path}/rancher_bootstrap"
  rancher_helm_chart_values       = var.rancher_helm_chart_values
  rancher_helm_chart_use_strategy = var.rancher_helm_chart_use_strategy
}

module "deploy_rancher" {
  source = "../deploy"
  depends_on = [
  ]
  deploy_path   = local.deploy_path
  data_path     = local.deploy_path
  template_path = local.rancher_path
  skip_destroy  = true # this is a one way operation, uninstall not supported
  environment_variables = {
    KUBECONFIG       = "${local.path}/kubeconfig"
    KUBE_CONFIG_PATH = "${local.path}/kubeconfig"
  }
  inputs = <<-EOT
    project_domain                  = "${local.project_domain}"
    rancher_version                 = "${local.rancher_version}"
    rancher_helm_repo               = "${local.rancher_helm_repo}"
    rancher_helm_channel            = "${local.rancher_helm_channel}"
    rancher_helm_chart_use_strategy = "${local.rancher_helm_chart_use_strategy}"
    rancher_helm_chart_values       = "${base64encode(jsonencode(local.rancher_helm_chart_values))}"
    zone_id                         = "${local.zone_id}"
    region                          = "${local.region}"
    email                           = "${local.email}"
    cert_manager_version            = "${local.cert_manager_version}"
    acme_server_url                 = "${local.acme_server_url}"
  EOT
}
