locals {
  rancher_domain  = var.rancher_domain
  ca_certs        = var.ca_certs
  path            = var.path
  deploy_path     = "${local.path}/bootstrap_rancher"
  data_path       = local.deploy_path
  bootstrap_path  = "${path.module}/bootstrap"
  kubeconfig_path = "../kubeconfig" # relative to deploy path
  admin_password  = var.admin_password
}

module "bootstrap" {
  source      = "../deploy"
  deploy_path = local.deploy_path
  data_path   = local.data_path
  template_files = [
    join("/", [local.bootstrap_path, "main.tf"]),
    join("/", [local.bootstrap_path, "outputs.tf"]),
    join("/", [local.bootstrap_path, "variables.tf"]),
    join("/", [local.bootstrap_path, "versions.tf"]),
  ]
  attempts     = 5
  interval     = 60
  skip_destroy = true # this is a one way operation, un-bootstrap not supported
  # if any of these change, redeploy/update
  deploy_trigger = md5(join("-", [
    local.rancher_domain,
    local.ca_certs,
  ]))
  environment_variables = {
    KUBECONFIG       = local.kubeconfig_path
    KUBE_CONFIG_PATH = local.kubeconfig_path
  }
  inputs = <<-EOT
    rancher_domain                  = "${local.rancher_domain}"
    ca_certs                        = "${base64encode(local.ca_certs)}"
    admin_password                  = "${local.admin_password}"
  EOT
}
