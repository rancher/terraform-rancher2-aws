# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  rancher_domain          = var.project_domain
  zone                    = var.zone
  project_cert_name       = var.project_cert_name
  project_cert_key_id     = var.project_cert_key_id
  path                    = var.path
  cert_manager_version    = var.cert_manager_version
  configure_cert_manager  = var.configure_cert_manager
  cert_manager_configured = (local.configure_cert_manager ? "configured" : "unconfigured")
  cert_manager_path       = "${abspath(path.module)}/${local.cert_manager_configured}"
}

resource "terraform_data" "path" {
  triggers_replace = {
    main_contents      = md5(file("${local.cert_manager_path}/main.tf"))
    variables_contents = md5(file("${local.cert_manager_path}/variables.tf"))
    versions_contents  = md5(file("${local.cert_manager_path}/versions.tf"))
  }
  provisioner "local-exec" {
    command = <<-EOT
      install -d ${local.path}/install_cert_manager
      cp ${local.cert_manager_path}/* ${local.path}/install_cert_manager/
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
    project_cert_name          = "${local.project_cert_name}"
    project_cert_key_id        = "${local.project_cert_key_id}"
    cert_manager_version       = "${local.cert_manager_version}"
    configure_cert_manager     = "${local.configure_cert_manager}"
  EOT
  filename = "${local.path}/install_cert_manager/inputs.tfvars"
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
      TF_DATA_DIR="${local.path}/install_cert_manager"
      cd ${local.path}/install_cert_manager
      terraform init -upgrade=true
      EXITCODE=1
      ATTEMPTS=0
      MAX=1
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        timeout 3600 terraform apply -var-file="inputs.tfvars" -auto-approve -state="${abspath(local.path)}/install_cert_manager/tfstate"
        EXITCODE=$?
        ATTEMPTS=$((ATTEMPTS+1))
      done
      exit $EXITCODE
    EOT
  }
}
