${export_contents}
cd ${deploy_path}
TF_CLI_ARGS_init=""
TF_CLI_ARGS_apply=""
export TF_DATA_DIR="${tf_data_dir}"
if [ -z "${skip_destroy}" ]; then
  timeout -k 1m ${timeout} terraform init -upgrade
  timeout -k 1m ${timeout} terraform destroy -var-file="${deploy_path}/inputs.tfvars" -auto-approve -state="${deploy_path}/tfstate" || true
else
  echo "Not destroying deployed module, it will no longer be managed here."
fi
