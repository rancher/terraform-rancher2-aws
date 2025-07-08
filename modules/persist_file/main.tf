locals {
  full_path  = abspath(var.path) # where to place the file
  contents   = var.contents      # the contents to persist
  sourcefile = var.sourcefile    # the sourcefile to persist
  recreate   = var.recreate      # when this changes update the persisted data to match contents

  # tflint-ignore: terraform_unused_declarations
  fail_no_source = ((local.contents == "" && local.sourcefile == "") ? one([local.contents, "missing_something_to_persist"]) : false)

  data = (local.contents != "" ? local.contents : data.external.read_file.result.data)
}

resource "terraform_data" "recreate" {
  input = local.recreate
}

data "external" "read_file" {
  depends_on = [
    terraform_data.recreate,
  ]
  program = ["bash", "${path.module}/read_file.sh"]
  query = {
    filepath = local.sourcefile
  }
}

resource "terraform_data" "snapshot" {
  depends_on = [
    data.external.read_file,
    terraform_data.recreate,
  ]
  input = local.data
  # we want this data to persist even if the input data changes
  # the point of this is so that we control when the data is updated ie. when the snapshot is saved/updated
  lifecycle {
    ignore_changes = [
      input,
    ]
  }
  triggers_replace = [
    terraform_data.recreate.output,
  ]
}

resource "local_sensitive_file" "file" {
  depends_on = [
    data.external.read_file,
    terraform_data.recreate,
    terraform_data.snapshot,
  ]
  filename = local.full_path
  content  = terraform_data.snapshot.output
}
