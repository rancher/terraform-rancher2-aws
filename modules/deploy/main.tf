# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  # template_files is a map of relative_path => absolute_path
  template_file_map = {
    for k, v in var.template_files : trimprefix(k, "./") => v
    if !startswith(k, "/") && length(regexall("(^|/)\\.\\.(/|$)", k)) == 0
  }
  generated_files = {
    for k, v in var.generated_files : trimprefix(k, "./") => v
    if k != "." && k != ".." && k != "" && v != "" && !startswith(k, "/") && length(regexall("(^|/)\\.\\.(/|$)", k)) == 0
  }

  # Generate all parent directories needed (including nested levels)
  # file_directory will create intermediate directories if they don't exist
  all_parent_dirs = toset([
    for k in concat(keys(local.template_file_map), keys(local.generated_files)) : dirname(k) if(
      dirname(k) != "" &&
      dirname(k) != "." &&
      dirname(k) != ".." &&
      dirname(k) != "/"
    )
  ])

  inputs                = var.inputs
  environment_variables = merge(var.environment_variables, { "TF_DATA_DIR" = local.tf_data_dir })
  export_contents = (
    local.environment_variables != null ?
    join(";", [for k, v in local.environment_variables : "export ${k}=${v}"])
    : ""
  )

  deploy_trigger = var.deploy_trigger
  deploy_path    = chomp(var.deploy_path)
  plugin_path    = var.plugin_cache_path == "" ? "${local.tf_data_dir}/plugins" : chomp(var.plugin_cache_path)
  root_path      = abspath(path.root)
  module_path    = abspath(path.module)

  attempts     = var.attempts
  interval     = var.interval
  timeout      = var.timeout
  init         = var.init
  init_script  = (local.init ? "terraform init -reconfigure -upgrade" : "")
  tf_data_dir  = (var.data_path != null ? var.data_path : local.root_path)
  skip_destroy = (var.skip_destroy ? "true" : "")
  jitter_min   = var.jitter_min
  jitter_max   = var.jitter_max
}

resource "file_local_directory" "deploy_path" {
  path        = local.deploy_path
  permissions = "0755"
}

resource "file_local_directory" "tf_data_dir" {
  depends_on = [
    file_local_directory.deploy_path,
  ]
  count       = (local.tf_data_dir != local.deploy_path ? 1 : 0)
  path        = local.tf_data_dir
  permissions = "0755"
}

### Template Files ###
# Read files from source (each.value = absolute source path)
data "file_local" "template_files" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
  ]
  for_each  = local.template_file_map
  directory = dirname(each.value)
  name      = basename(each.value)
}

# Create all parent directories for template files in deploy_path (including nested levels)
resource "file_local_directory" "template_dirs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
  ]
  for_each    = local.all_parent_dirs
  path        = "${local.deploy_path}/${each.key}"
  permissions = "0755"
}

# Snapshot template files
resource "file_local_snapshot" "persist_tpl_file" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    data.file_local.template_files,
  ]
  for_each       = local.template_file_map
  directory      = dirname(each.value)
  name           = basename(each.value)
  update_trigger = local.deploy_trigger
}

# Copy files to deploy_path preserving directory structure (each.key = relative path)
resource "file_local" "instantiate_tpl_snapshot" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    data.file_local.template_files,
    file_local_snapshot.persist_tpl_file,
  ]
  for_each    = local.template_file_map
  directory   = dirname("${local.deploy_path}/${each.key}")
  name        = basename(each.key)
  permissions = data.file_local.template_files[each.key].permissions
  contents    = base64decode(file_local_snapshot.persist_tpl_file[each.key].snapshot)
}

### Inputs ###
resource "file_local" "write_tmp_inputs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
  ]
  directory   = local.tf_data_dir
  name        = "inputs.tmp"
  contents    = local.inputs
  permissions = "0600"
}
resource "file_local_snapshot" "persist_inputs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
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
    file_local_directory.template_dirs,
    file_local.write_tmp_inputs,
    file_local_snapshot.persist_inputs,
  ]
  directory   = local.deploy_path
  name        = "inputs.tfvars"
  contents    = base64decode(file_local_snapshot.persist_inputs.snapshot)
  permissions = "0600"
}

### Environment Variables ###
resource "file_local" "write_tmp_env" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
  ]
  directory   = local.tf_data_dir
  name        = "env.tmp"
  contents    = local.export_contents
  permissions = "0600"
}
resource "file_local_snapshot" "persist_envrc" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
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
    file_local_directory.template_dirs,
    file_local.write_tmp_env,
    file_local_snapshot.persist_envrc,
  ]
  directory   = local.deploy_path
  name        = "envrc"
  contents    = base64decode(file_local_snapshot.persist_envrc.snapshot)
  permissions = "0600"
}

## Generated Files ##
resource "file_local" "generate_files" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
  ]
  for_each    = local.generated_files
  directory   = dirname("${local.deploy_path}/${each.key}")
  name        = basename(each.key)
  contents    = each.value
  permissions = "0600"
}

## Deploy ##
resource "file_local" "generate_destroy" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
  ]
  directory   = local.tf_data_dir
  name        = "destroy.sh"
  permissions = "0755"
  contents = templatefile("${local.module_path}/destroy.sh.tpl", {
    deploy_path  = local.deploy_path
    plugin_cache = local.plugin_path
    skip_destroy = local.skip_destroy
    timeout      = local.timeout
  })
}
resource "terraform_data" "destroy" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
    file_local.generate_destroy,
  ]
  triggers_replace = {
    trigger = local.deploy_trigger
    dp      = local.tf_data_dir
  }
  provisioner "local-exec" {
    when = destroy
    # no changing the directory or this won't work on different machines!
    command = <<-EOT
      # if the original filesystem is wiped out, the destroy script may not exist on a consecutive apply (not the first apply)
      # in which case we need the generate_destroy resource to regenerate the destroy script, and the destroy_end resource will handle the destroy.
      if [ -f ${self.triggers_replace.dp}/destroy.sh ]; then
        ${self.triggers_replace.dp}/destroy.sh
      fi
    EOT
  }
}

resource "file_local" "generate_create" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
    terraform_data.destroy,
  ]
  directory   = local.tf_data_dir
  name        = "create.sh"
  permissions = "0755"
  contents = templatefile("${local.module_path}/create.sh.tpl", {
    deploy_path  = local.deploy_path
    plugin_cache = local.plugin_path
    init_script  = local.init_script
    attempts     = local.attempts
    timeout      = local.timeout
    interval     = local.interval
  })
}
resource "terraform_data" "create" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
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
      if [ ${local.jitter_max} -gt 0 ]; then
        # Seed awk with the time + shell PID to prevent identical jitters in parallel executions
        JITTER=$(awk -v seed="$(( $(date +%s) + $$ ))" 'BEGIN{srand(seed); print int(${local.jitter_min} + rand() * ${local.jitter_max - local.jitter_min + 1})}')
        echo "Applying random jitter of $JITTER seconds..."
        sleep $JITTER
      fi
      
      ${local.tf_data_dir}/create.sh
    EOT
  }
}

resource "file_local_snapshot" "persist_state" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
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
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
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
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
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
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
    terraform_data.destroy,
    terraform_data.create,
    file_local_snapshot.persist_outputs,
  ]
  directory = local.deploy_path
  name      = "outputs.json"
  contents  = base64decode(file_local_snapshot.persist_outputs.snapshot)
}
data "file_local" "outputs" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
    terraform_data.destroy,
    terraform_data.create,
    file_local_snapshot.persist_outputs,
    file_local.instantiate_outputs,
  ]
  directory = local.deploy_path
  name      = "outputs.json"
}
# during initial create this should be an extra apply that has no effect
# when the inputs change and the template needs to be rebuilt this will allow the persist
#  to rebuild the template and state file before running the create script
resource "terraform_data" "create_after_persist" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
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
      if [ ${local.jitter_max} -gt 0 ]; then
        # Seed awk with the time + shell PID to prevent identical jitters in parallel executions
        JITTER=$(awk -v seed="$(( $(date +%s) + $$ ))" 'BEGIN{srand(seed); print int(${local.jitter_min} + rand() * ${local.jitter_max - local.jitter_min + 1})}')
        echo "Applying random jitter of $JITTER seconds..."
        sleep $JITTER
      fi

      ${local.tf_data_dir}/create.sh "CREATE_AFTER_PERSIST=true"
    EOT
  }
}

resource "terraform_data" "destroy_end" {
  depends_on = [
    file_local_directory.deploy_path,
    file_local_directory.tf_data_dir,
    file_local_directory.template_dirs,
    file_local.instantiate_envrc_snapshot,
    file_local.instantiate_inputs_snapshot,
    file_local.instantiate_tpl_snapshot,
    file_local.generate_files,
    terraform_data.destroy,
    terraform_data.create,
    file_local.generate_destroy,
    file_local.generate_create,
    file_local.instantiate_state,
    file_local.instantiate_outputs,
    terraform_data.create_after_persist,
  ]
  triggers_replace = {
    dp = local.tf_data_dir
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ${self.triggers_replace.dp}/destroy.sh
    EOT
  }
}
