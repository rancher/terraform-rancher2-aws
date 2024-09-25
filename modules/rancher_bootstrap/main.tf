# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  rancher_domain          = var.project_domain
  rancher_version         = replace(var.rancher_version, "v", "") # don't include the v
  rancher_helm_repository = var.rancher_helm_repository
  cert_manager_version    = var.cert_manager_version
  project_cert_name       = var.project_cert_name
  project_cert_key_id     = var.project_cert_key_id
  path                    = var.path
  path_script             = <<-EOT
    install -d ${local.path}/rancher_bootstrap
    cp ${abspath(path.module)}/tf.bootstrap        ${local.path}/rancher_bootstrap/main.tf
    cp ${abspath(path.module)}/variables.tf        ${local.path}/rancher_bootstrap/variables.tf
    cp ${abspath(path.module)}/versions.tf         ${local.path}/rancher_bootstrap/versions.tf
    cp ${abspath(path.module)}/tf.bootstrap_output ${local.path}/rancher_bootstrap/outputs.tf
  EOT
  inputs_content          = <<-EOT
    project_domain          = "${local.rancher_domain}"
    rancher_version         = "${local.rancher_version}"
    rancher_helm_repository = "${local.rancher_helm_repository}"
    cert_manager_version    = "${local.cert_manager_version}"
    project_cert_name       = "${local.project_cert_name}"
    project_cert_key_id     = "${local.project_cert_key_id}"
  EOT
  create_script           = <<-EOT
    export KUBECONFIG=${abspath(local.path)}/kubeconfig
    export KUBE_CONFIG_PATH=${abspath(local.path)}/kubeconfig
    TF_DATA_DIR="${local.path}/rancher_bootstrap"
    cd ${local.path}/rancher_bootstrap
    terraform init -upgrade=true
    terraform apply -var-file="inputs.tfvars" -auto-approve -state="${abspath(local.path)}/rancher_bootstrap/tfstate"
    terraform output -state="${abspath(local.path)}/rancher_bootstrap/tfstate" -json > ${abspath(local.path)}/output.json
  EOT
  destroy_script          = <<-EOT
    export KUBECONFIG=${abspath(local.path)}/kubeconfig
    export KUBE_CONFIG_PATH=${abspath(local.path)}/kubeconfig
    TF_DATA_DIR="${local.path}/rancher_bootstrap"
    cd ${local.path}/rancher_bootstrap
    terraform destroy -var-file="inputs.tfvars" -auto-approve -state="${abspath(local.path)}/rancher_bootstrap/tfstate"
  EOT
}

resource "terraform_data" "path" {
  triggers_replace = {
    script_contents    = local.path_script,
    bootstrap_contents = md5(file("${path.module}/tf.bootstrap"))
    variables_contents = md5(file("${path.module}/variables.tf"))
    versions_contents  = md5(file("${path.module}/versions.tf"))
    outputs_contents   = md5(file("${path.module}/tf.bootstrap_output"))
  }
  provisioner "local-exec" {
    command = local.path_script
  }
}

resource "local_file" "inputs" {
  depends_on = [
    terraform_data.path,
  ]
  content  = local.inputs_content
  filename = "${local.path}/rancher_bootstrap/inputs.tfvars"
}

resource "terraform_data" "create" {
  depends_on = [
    terraform_data.path,
    local_file.inputs,
  ]
  triggers_replace = {
    path               = local.path
    inputs             = local_file.inputs.content
    path_script        = local.path_script
    create_script      = local.create_script
    destroy_script     = local.destroy_script
    bootstrap_contents = md5(file("${path.module}/tf.bootstrap"))
    variables_contents = md5(file("${path.module}/variables.tf"))
    versions_contents  = md5(file("${path.module}/versions.tf"))
    outputs_contents   = md5(file("${path.module}/tf.bootstrap_output"))
  }
  provisioner "local-exec" {
    command = local.create_script
  }
  provisioner "local-exec" {
    # warning! this is only triggered on destroy, not refresh/taint
    when    = destroy
    command = self.triggers_replace.destroy_script
  }
}

data "external" "output" {
  depends_on = [
    terraform_data.path,
    local_file.inputs,
    terraform_data.create,
  ]
  program = ["bash", "${path.module}/get_terraform_output.sh"]
  query = {
    data = "${abspath(local.path)}/output.json"
  }
}
