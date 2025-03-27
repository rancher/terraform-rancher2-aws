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
  cert_manager_path       = "${abspath(path.module)}/${local.cert_manager_configured}"
  cert_manager_config     = var.cert_manager_configuration
  deploy_path             = "${local.path}/install_cert_manager/"
  backend_file            = var.backend_file
}

resource "terraform_data" "path" {
  triggers_replace = {
    main_contents      = md5(file("${local.cert_manager_path}/main.tf"))
    variables_contents = md5(file("${local.cert_manager_path}/variables.tf"))
    versions_contents  = md5(file("${local.cert_manager_path}/versions.tf"))
    backend_contents   = (local.backend_file == "" ? "" : md5(file("${local.backend_file}")))
  }
  provisioner "local-exec" {
    command = <<-EOT
      install -d ${local.deploy_path}
      cp ${local.cert_manager_path}/* ${local.deploy_path}
      cp "${abspath(path.root)}/.terraform.lock.hcl" ${local.deploy_path}
      if [ -f "${local.backend_file}" ]; then
        cp ${local.backend_file} ${local.deploy_path}
      fi
      if [ -z "$TF_DATA_DIR" ]; then
        cp -r "${abspath(path.root)}/.terraform" ${local.deploy_path}
      else
        install -d ${local.deploy_path}/.terraform
        cp -r $TF_DATA_DIR/modules ${local.deploy_path}/.terraform
        cp -r $TF_DATA_DIR/providers ${local.deploy_path}/.terraform
      fi
    EOT
  }
}

resource "local_file" "inputs" {
  depends_on = [
    terraform_data.path,
  ]
  lifecycle {
    replace_triggered_by = [
      terraform_data.path.id,
    ]
  }
  content  = <<-EOT
    project_domain             = "${local.rancher_domain}"
    zone                       = "${local.zone}"
    zone_id                    = "${local.zone_id}"
    project_cert_name          = "${local.project_cert_name}"
    project_cert_key_id        = "${local.project_cert_key_id}"
    cert_manager_version       = "${local.cert_manager_version}"
    configure_cert_manager     = "${local.configure_cert_manager}"
    cert_manager_configuration = {
      aws_region            = "${local.cert_manager_config.aws_region}"
      aws_session_token     = "${local.cert_manager_config.aws_session_token}"
      aws_access_key_id     = "${local.cert_manager_config.aws_access_key_id}"
      aws_secret_access_key = "${local.cert_manager_config.aws_secret_access_key}"
    }
  EOT
  filename = "${local.path}/install_cert_manager/inputs.tfvars"
}

# this is a one way operation, there is no destroy or update
resource "terraform_data" "create" {
  depends_on = [
    terraform_data.path,
    local_file.inputs,
  ]
  triggers_replace = {
    path_data   = terraform_data.path.id
    inputs_data = local_file.inputs.id
  }
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${abspath(local.path)}/kubeconfig
      export KUBE_CONFIG_PATH=${abspath(local.path)}/kubeconfig
      TF_DATA_DIR="${local.path}/install_cert_manager"
      cd ${local.path}/install_cert_manager
      if [ -z "$TF_PLUGIN_CACHE_DIR" ]; then
        terraform init -upgrade=true
      else
        echo "skipping terraform init in submodule in favor of plugin cache directory..."
      fi
      EXITCODE=1
      ATTEMPTS=0
      MAX=1
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        timeout 3600 terraform apply -var-file="inputs.tfvars" -auto-approve -state="${abspath(local.path)}/install_cert_manager/tfstate"
        EXITCODE=$?
        ATTEMPTS=$((ATTEMPTS+1))
        echo "waiting 30 seconds between attempts..."
        sleep 30
      done
      exit $EXITCODE
    EOT
  }
}
