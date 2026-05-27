output "output" {
  # v.value because outputs.json has more than one attribute for the value parameter 
  # (eg. v.sensitive) and we just want the actual output values
  value = { for k, v in jsondecode(data.file_local.outputs.contents) : k => v.value }
}
