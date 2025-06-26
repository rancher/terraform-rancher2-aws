output "output" {
  value = { for k, v in jsondecode(module.persist_outputs.contents) : k => v.value }
}

# output "raw_output" {
#   value = module.persist_outputs.contents
# }

# output "state" {
#   value = module.persist_state.contents
# }
