# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  rancher_domain       = var.project_domain
  zone                 = var.zone
  zone_id              = var.zone_id
  region               = var.region
  email                = var.email
  acme_server_url      = var.acme_server_url
  rancher_version      = replace(var.rancher_version, "v", "") # don't include the v
  cert_manager_version = var.cert_manager_version
  cert_manager_config  = var.cert_manager_configuration
  externalTLS          = var.externalTLS
  path                 = var.path
  rancher_path         = (local.externalTLS ? "${abspath(path.module)}/rancher_externalTLS" : "${abspath(path.module)}/rancher")
  deploy_path          = "${abspath(local.path)}/rancher_bootstrap"
  backend_file         = var.backend_file
}

resource "terraform_data" "path" {
  triggers_replace = {
    main_contents      = md5(file("${local.rancher_path}/main.tf"))
    variables_contents = md5(file("${local.rancher_path}/variables.tf"))
    versions_contents  = md5(file("${local.rancher_path}/versions.tf"))
    outputs_contents   = md5(file("${local.rancher_path}/outputs.tf"))
    backend_contents   = (local.backend_file == "" ? "" : md5(file(local.backend_file)))
  }
  provisioner "local-exec" {
    command = <<-EOT
      install -d ${local.deploy_path}
      install -d ${local.deploy_path}/.terraform
      cp --remove-destination ${local.rancher_path}/* ${local.deploy_path}
      cp --remove-destination "${abspath(path.root)}/.terraform.lock.hcl" ${local.deploy_path}
      if [ -f "${local.backend_file}" ]; then
        cp --remove-destination ${local.backend_file} ${local.deploy_path}
      fi
      if [ -z "$TF_DATA_DIR" ]; then
        echo "copying terraform data from default location..."
        cp -rf --remove-destination "${abspath(path.root)}/.terraform" ${local.deploy_path}
      else
        echo "copying terraform data from $TF_DATA_DIR..."
        cp -rf --remove-destination "$TF_DATA_DIR/modules"   ${local.deploy_path}/.terraform
        cp -rf --remove-destination "$TF_DATA_DIR/providers" ${local.deploy_path}/.terraform
      fi
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
    zone_id                    = "${local.zone_id}"
    region                     = "${local.region}"
    email                      = "${local.email}"
    acme_server_url            = "${local.acme_server_url}"
    rancher_version            = "${local.rancher_version}"
    cert_manager_version       = "${local.cert_manager_version}"
    cert_manager_configuration = {
      aws_region            = "${local.cert_manager_config.aws_region}"
      aws_access_key_id     = "${local.cert_manager_config.aws_access_key_id}"
      aws_secret_access_key = "${local.cert_manager_config.aws_secret_access_key}"
      aws_session_token     = "${local.cert_manager_config.aws_session_token}"
    }
    path                       = "${local.deploy_path}"
  EOT
  filename = "${local.deploy_path}/inputs.tfvars"
}

resource "terraform_data" "create" {
  depends_on = [
    terraform_data.path,
    local_file.inputs,
  ]
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${abspath(local.path)}/kubeconfig
      export KUBE_CONFIG_PATH=${abspath(local.path)}/kubeconfig
      cd ${local.deploy_path}

      MAX=2
      EXITCODE=1
      ATTEMPTS=0
      E=1
      E1=0
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
        A=0
        while [ $E -gt 0 ] && [ $A -lt $MAX ]; do
          timeout 1h terraform apply -var-file="inputs.tfvars" -auto-approve -state="${local.deploy_path}/tfstate"
          E=$?
          if [ $E -eq 124 ]; then echo "Apply timed out after 1 hour"; fi
          A=$((A+1))
        done
        # don't destroy if the last attempt fails
        if [ $E -gt 0 ] && [ $ATTEMPTS != $((MAX-1)) ]; then
          A1=0
          while [ $E1 -gt 0 ] && [ $A1 -lt $MAX ]; do
            timeout 1h terraform destroy -var-file="inputs.tfvars" -auto-approve -state="${local.deploy_path}/tfstate"
            E1=$?
            if [ $E1 -eq 124 ]; then echo "Apply timed out after 1 hour"; fi
            A1=$((A1+1))
          done
        fi
        if [ $E -gt 0 ]; then
          echo "apply failed..."
        fi
        if [ $E1 -gt 0 ]; then
          echo "destroy failed..."
        fi
        if [ $E -gt 0 ] || [ $E1 -gt 0 ]; then
          EXITCODE=1
        else
          EXITCODE=0
        fi
        ATTEMPTS=$((ATTEMPTS+1))
        if [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; then
          echo "wait 30 seconds between attempts..."
          sleep 30
        fi
      done
      if [ $ATTEMPTS -eq $MAX ]; then echo "max attempts reached..."; fi
      if [ $EXITCODE -ne 0 ]; then echo "failure, exit code $EXITCODE..."; fi
      if [ $EXITCODE -eq 0 ]; then echo "success..."; fi
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
