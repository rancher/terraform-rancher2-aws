# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  template_files    = var.template_files
  template_file_map = { for file in local.template_files : basename(file) => file }

  # template_file_map     = { for i in range(length(local.template_files)) : tostring(i) => local.template_files[i] }
  # need to figure out how to copy the files sent, the for_each loop won't work due to the dynamic read of the directory
  inputs                = var.inputs
  environment_variables = merge(var.environment_variables, { "TF_DATA_DIR" = local.tf_data_dir })
  export_contents = (
    local.environment_variables != null ?
    join(";", [for k, v in local.environment_variables : "export ${k}=${v}"])
    : ""
  )

  deploy_trigger = var.deploy_trigger
  deploy_path    = chomp(var.deploy_path)
  attempts       = var.attempts
  interval       = var.interval
  timeout        = var.timeout
  init           = var.init
  init_script    = (local.init ? "terraform init -reconfigure -upgrade" : "")
  tf_data_dir    = (var.data_path != null ? var.data_path : path.root)
  skip_destroy   = (var.skip_destroy ? "true" : "")
}

resource "file_local_directory" "deploy_path" {
  path        = local.deploy_path
  permissions = "0755"
}
resource "file_local_directory" "tf_data_dir" {
  count       = (local.tf_data_dir != local.deploy_path ? 1 : 0)
  path        = local.tf_data_dir
  permissions = "0755"
}

### Template Files ###
data "file_local" "template_files" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
  ]
  for_each  = local.template_file_map
  directory = dirname(each.value)
  name      = each.key
}
resource "file_local_snapshot" "persist_tpl_file" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    data.file_local.template_files,
  ]
  for_each       = local.template_file_map
  directory      = dirname(each.value)
  name           = each.key
  update_trigger = local.deploy_trigger
}
resource "file_local" "instantiate_tpl_snapshot" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    data.file_local.template_files,
    file_local_snapshot.persist_tpl_file,
  ]
  for_each    = local.template_file_map
  directory   = local.deploy_path
  name        = each.key
  permissions = data.file_local.template_files[each.key].permissions
  contents    = base64decode(file_local_snapshot.persist_tpl_file[each.key].snapshot)
}

### Inputs ###
resource "file_local" "write_tmp_inputs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
  ]
  directory   = local.tf_data_dir
  name        = "inputs.tmp"
  contents    = local.inputs
  permissions = "0400"
}
resource "file_local_snapshot" "persist_inputs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.write_tmp_inputs,
  ]
  directory      = local.tf_data_dir
  name           = "inputs.tmp"
  update_trigger = local.deploy_trigger
}
resource "file_local" "instantiate_inputs_snapshot" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.write_tmp_inputs,
    file_local_snapshot.persist_inputs,
  ]
  directory = local.deploy_path
  name      = "inputs.tfvars"
  contents  = base64decode(file_local_snapshot.persist_inputs.snapshot)
}

### Environment Variables ###
resource "file_local" "write_tmp_env" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
  ]
  directory   = local.tf_data_dir
  name        = "env.tmp"
  contents    = local.export_contents
  permissions = "0400"
}
resource "file_local_snapshot" "persist_envrc" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.write_tmp_env,
  ]
  directory      = local.tf_data_dir
  name           = "env.tmp"
  update_trigger = local.deploy_trigger
}
resource "file_local" "instantiate_envrc_snapshot" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.write_tmp_env,
    file_local_snapshot.persist_envrc,
  ]
  directory   = local.deploy_path
  name        = "envrc"
  contents    = base64decode(file_local_snapshot.persist_envrc.snapshot)
  permissions = "0644"
}

## Deploy ##
resource "file_local" "generate_destroy" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
  ]
  directory   = local.tf_data_dir
  name        = "destroy.sh"
  permissions = "0755"
  contents = templatefile("${path.module}/destroy.sh.tpl", {
    deploy_path  = local.deploy_path
    skip_destroy = local.skip_destroy
    timeout      = local.timeout
  })
}
resource "terraform_data" "destroy" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_destroy,
  ]
  triggers_replace = {
    trigger = local.deploy_trigger
    dp      = local.deploy_path
  }
  provisioner "local-exec" {
    when = destroy
    # no changing the directory or this won't work on different machines!
    command = <<-EOT
      set -x
      ${self.triggers_replace.dp}/destroy.sh
    EOT
  }
}

resource "file_local" "generate_create" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    terraform_data.destroy,
  ]
  directory   = local.tf_data_dir
  name        = "create.sh"
  permissions = "0755"
  contents = templatefile("${path.module}/create.sh.tpl", {
    deploy_path = local.deploy_path
    init_script = local.init_script
    attempts    = local.attempts
    timeout     = local.timeout
    interval    = local.interval
  })
}
resource "terraform_data" "create" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_create,
    file_local.generate_destroy,
    terraform_data.destroy,
  ]
  triggers_replace = {
    never = <<-EOT
      This resource is only meant to run once, on the initial deploy,
      the second create (create_after_persist) manages updates.
    EOT
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -x
      ${local.tf_data_dir}/create.sh
    EOT
  }
}

resource "file_local_snapshot" "persist_state" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    terraform_data.destroy,
    terraform_data.create,
  ]
  directory      = local.deploy_path
  name           = "tfstate"
  update_trigger = terraform_data.create.id
}
resource "file_local" "instantiate_state" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    terraform_data.destroy,
    terraform_data.create,
    file_local_snapshot.persist_state,
  ]
  directory = local.deploy_path
  name      = "tfstate"
  contents  = base64decode(file_local_snapshot.persist_state.snapshot)
}

resource "file_local_snapshot" "persist_outputs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    terraform_data.destroy,
    terraform_data.create,
  ]
  directory      = local.deploy_path
  name           = "outputs.json"
  update_trigger = terraform_data.create.id
}
resource "file_local" "instantiate_outputs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    terraform_data.destroy,
    terraform_data.create,
    file_local_snapshot.persist_outputs,
  ]
  directory = local.deploy_path
  name      = "outputs.json"
  contents  = base64decode(file_local_snapshot.persist_outputs.snapshot)
}

# during initial create this should be an extra apply that has no effect
# when the inputs change and the template needs to be rebuilt this will allow the persist
#  to rebuild the template and state file before running the create script
resource "terraform_data" "create_after_persist" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_destroy,
    file_local.generate_create,
    terraform_data.destroy,
    terraform_data.create,
    file_local.instantiate_state,
    file_local.instantiate_outputs,
  ]
  triggers_replace = {
    trigger = local.deploy_trigger
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -x
      ${local.tf_data_dir}/create.sh
    EOT
  }
}

resource "terraform_data" "destroy_end" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    terraform_data.destroy,
    terraform_data.create,
    file_local.generate_destroy,
    file_local.generate_create,
    file_local.instantiate_state,
    file_local.instantiate_outputs,
    terraform_data.create_after_persist,
  ]
  triggers_replace = {
    dp = local.deploy_path
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -x
      ${self.triggers_replace.dp}/destroy.sh
    EOT
  }
}
