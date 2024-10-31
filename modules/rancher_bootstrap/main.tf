# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  rancher_domain          = var.project_domain
  zone                    = var.zone
  region                  = var.region
  email                   = var.email
  rancher_version         = replace(var.rancher_version, "v", "") # don't include the v
  rancher_helm_repository = var.rancher_helm_repository
  cert_manager_version    = var.cert_manager_version
  cert_manager_config     = var.cert_manager_configuration
  externalTLS             = var.externalTLS
  path                    = var.path
  rancher_path            = (local.externalTLS ? "${abspath(path.module)}/rancher_externalTLS" : "${abspath(path.module)}/rancher")
  deploy_path             = "${abspath(local.path)}/rancher_bootstrap"
}

resource "terraform_data" "path" {
  triggers_replace = {
    main_contents      = md5(file("${local.rancher_path}/main.tf"))
    variables_contents = md5(file("${local.rancher_path}/variables.tf"))
    versions_contents  = md5(file("${local.rancher_path}/versions.tf"))
    outputs_contents   = md5(file("${local.rancher_path}/outputs.tf"))
  }
  provisioner "local-exec" {
    command = <<-EOT
      install -d ${local.deploy_path}
      cp ${local.rancher_path}/* ${local.deploy_path}/
    EOT
  }
}

resource "local_file" "inputs" {
  depends_on = [
    terraform_data.path,
  ]
  content  = <<-EOT
    project_domain             = "${local.rancher_domain}"
    zone                       = "${local.zone}"
    region                     = "${local.region}"
    email                      = "${local.email}"
    rancher_version            = "${local.rancher_version}"
    rancher_helm_repository    = "${local.rancher_helm_repository}"
    cert_manager_version       = "${local.cert_manager_version}"
    cert_manager_configuration = {
      aws_access_key_id     = "${local.cert_manager_config.aws_access_key_id}"
      aws_secret_access_key = "${local.cert_manager_config.aws_secret_access_key}"
      aws_region            = "${local.cert_manager_config.aws_region}"
      email                 = "${local.cert_manager_config.email}"
    }
    path                       = "${local.deploy_path}"
  EOT
  filename = "${local.deploy_path}/inputs.tfvars"
}

# this is a one way operation, there is no destroy or update
resource "terraform_data" "create" {
  depends_on = [
    terraform_data.path,
    local_file.inputs,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${abspath(local.path)}/kubeconfig
      export KUBE_CONFIG_PATH=${abspath(local.path)}/kubeconfig
      TF_DATA_DIR="${local.deploy_path}"
      cd ${local.deploy_path}
      terraform init -upgrade=true
      EXITCODE=1
      ATTEMPTS=0
      MAX=3
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        timeout 3600 terraform apply -var-file="inputs.tfvars" -auto-approve -state="${local.deploy_path}/tfstate"
        EXITCODE=$?
        ATTEMPTS=$((ATTEMPTS+1))
      done
      exit $EXITCODE
    EOT
  }
}

data "terraform_remote_state" "rancher_bootstrap_state" {
  depends_on = [
    terraform_data.path,
    local_file.inputs,
    terraform_data.create,
  ]
  backend = "local"
  config = {
    path = "${local.deploy_path}/tfstate"
  }
}
