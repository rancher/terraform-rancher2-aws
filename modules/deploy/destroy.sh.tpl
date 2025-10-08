set -x
pushd ${deploy_path}
pwd
ls -lah
. envrc
TF_CLI_ARGS_init=""
TF_CLI_ARGS_apply=""
if [ -z "${skip_destroy}" ]; then
  timeout -k 1m ${timeout} terraform init -upgrade -reconfigure
  timeout -k 1m ${timeout} terraform destroy -var-file="${deploy_path}/inputs.tfvars" -auto-approve -state="${deploy_path}/tfstate" || true
else
  echo "Not destroying deployed module, it will no longer be managed here."
fi
popd
