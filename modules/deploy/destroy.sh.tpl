set -x
DIR=$(pwd)
cd ${deploy_path}
pwd
ls -lah
whoami
. ${deploy_path}/envrc
TF_CLI_ARGS_init=""
TF_CLI_ARGS_apply=""
if [ -z "${skip_destroy}" ]; then
  timeout -k 1m ${timeout} terraform init -upgrade -reconfigure -no-color
  timeout -k 1m ${timeout} terraform destroy -var-file="${deploy_path}/inputs.tfvars" -no-color -auto-approve -state="${deploy_path}/tfstate" || true
else
  echo "Not destroying deployed module, it will no longer be managed here."
fi
cd $DIR
exit 0
