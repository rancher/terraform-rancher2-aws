output "output" {
  value = { for k, v in jsondecode(base64decode(file_local_snapshot.persist_outputs.snapshot)) : k => v.value }
}

# output "raw_output" {
#   value = module.persist_outputs.contents
# }

# output "state" {
#   value = module.persist_state.contents
# }
