output "admin_token" {
  value     = data.terraform_remote_state.rancher_bootstrap_state.outputs.admin_token
  sensitive = true
}

output "admin_password" {
  value     = data.terraform_remote_state.rancher_bootstrap_state.outputs.admin_password
  sensitive = true
}

output "rancher_bootstrap_state_location" {
  value     = "${local.deploy_path}/tfstate"
  sensitive = true
}
