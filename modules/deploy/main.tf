# There are many ways to orchestrate Terraform configurations with the goal of breaking it down
# I am using Terraform resources to orchestrate Terraform
# I felt this was the best way to accomplish the goal without incurring additional dependencies

locals {
  inputs         = var.inputs
  inputs_hash    = md5(local.inputs)
  template_path  = var.template_path
  template_files = var.template_files
  # tflint-ignore: terraform_unused_declarations
  fail_no_template = ((local.template_path == null && length(local.template_files) == 0) ? one([local.template_path, "missing_template"]) : false)
  # tflint-ignore: terraform_unused_declarations
  fail_too_much_template = ((local.template_path != null && length(local.template_files) > 0) ? one([local.template_path, "template_path_or_template_files"]) : false)
  template_file_list = (
    local.template_path != null ?
    [
      for i in range(length(fileset(local.template_path, "**"))) :
      join("/", [local.template_path, tolist(fileset(local.template_path, "**"))[i]])
    ]
    : local.template_files
  )
  template_file_map   = { for file in local.template_file_list : basename(file) => file }
  template_files_hash = md5(join("-", local.template_file_list))
  deploy_path         = chomp(var.deploy_path)

  environment_variables = var.environment_variables
  export_contents = (
    local.environment_variables != null ?
    join(";", [for k, v in local.environment_variables : "export ${k}=${v}"])
    : ""
  )
  export_hash  = md5(local.export_contents)
  attempts     = var.attempts
  interval     = var.interval
  timeout      = var.timeout
  init         = var.init
  init_script  = (local.init ? "terraform init -reconfigure -upgrade" : "")
  tf_data_dir  = var.data_path != null ? var.data_path : path.root
  skip_destroy = (var.skip_destroy ? "true" : "")
}

module "persist_template" {
  source = "../persist_file"
  depends_on = [
  ]
  for_each = local.template_file_map
  path     = "${local.deploy_path}/${each.key}"
  contents = file(each.value)
  recreate = filemd5(each.value)
}

module "persist_inputs" {
  source = "../persist_file"
  depends_on = [
  ]
  path     = "${local.deploy_path}/inputs.tfvars"
  contents = local.inputs
  recreate = md5(local.inputs)
}

resource "terraform_data" "destroy" {
  depends_on = [
    module.persist_template,
    module.persist_inputs,
  ]
  triggers_replace = {
    inputs = local.inputs_hash
    files  = local.template_files_hash
    env    = local.export_hash
    ec     = local.export_contents
    dp     = local.deploy_path
    to     = local.timeout
    dd     = local.tf_data_dir
    sd     = local.skip_destroy
  }
  provisioner "local-exec" {
    when = destroy
    command = templatefile("${path.module}/destroy.sh.tpl", {
      export_contents = self.triggers_replace.ec
      tf_data_dir     = self.triggers_replace.dd
      deploy_path     = self.triggers_replace.dp
      skip_destroy    = self.triggers_replace.sd
      timeout         = self.triggers_replace.to
    })
  }
}

resource "terraform_data" "create" {
  depends_on = [
    module.persist_template,
    module.persist_inputs,
    terraform_data.destroy,
  ]
  triggers_replace = {
    files = local.template_files_hash
  }
  provisioner "local-exec" {
    command = templatefile("${path.module}/create.sh.tpl", {
      export_contents = local.export_contents
      deploy_path     = local.deploy_path
      tf_data_dir     = local.tf_data_dir
      init_script     = local.init_script
      attempts        = local.attempts
      timeout         = local.timeout
      interval        = local.interval
    })
  }
}

module "persist_state" {
  depends_on = [
    module.persist_template,
    module.persist_inputs,
    terraform_data.destroy,
    terraform_data.create,
  ]
  source     = "../persist_file"
  path       = "${local.deploy_path}/tfstate"
  sourcefile = "${local.deploy_path}/tfstate"
  recreate   = terraform_data.create.id
}

module "persist_outputs" {
  depends_on = [
    module.persist_template,
    module.persist_inputs,
    terraform_data.destroy,
    terraform_data.create,
  ]
  source     = "../persist_file"
  path       = "${local.deploy_path}/outputs.json"
  sourcefile = "${local.deploy_path}/outputs.json"
  recreate   = terraform_data.create.id
}

# during initial create this should be an extra apply that has no effect
# when the inputs change and the template needs to be rebuilt this will allow the persist
#  to rebuild the template before running the create script
resource "terraform_data" "create_after_persist" {
  depends_on = [
    module.persist_template,
    module.persist_inputs,
    terraform_data.destroy,
    terraform_data.create,
    module.persist_state,
    module.persist_outputs,
  ]
  triggers_replace = {
    inputs = local.inputs_hash
    files  = local.template_files_hash
    env    = local.export_hash
  }
  provisioner "local-exec" {
    command = templatefile("${path.module}/create.sh.tpl", {
      export_contents = local.export_contents
      deploy_path     = local.deploy_path
      tf_data_dir     = local.tf_data_dir
      init_script     = local.init_script
      attempts        = local.attempts
      timeout         = local.timeout
      interval        = local.interval
    })
  }
}

resource "terraform_data" "destroy_end" {
  depends_on = [
    module.persist_template,
    module.persist_inputs,
    terraform_data.destroy,
    terraform_data.create,
    module.persist_state,
    module.persist_outputs,
    terraform_data.create_after_persist,
  ]
  triggers_replace = {
    inputs = local.inputs_hash
    files  = local.template_files_hash
    env    = local.export_hash
    ec     = local.export_contents
    dp     = local.deploy_path
    to     = local.timeout
    dd     = local.tf_data_dir
    sd     = local.skip_destroy
  }
  provisioner "local-exec" {
    when = destroy
    command = templatefile("${path.module}/destroy.sh.tpl", {
      export_contents = self.triggers_replace.ec
      tf_data_dir     = self.triggers_replace.dd
      deploy_path     = self.triggers_replace.dp
      skip_destroy    = self.triggers_replace.sd
      timeout         = self.triggers_replace.to
    })
  }
}
