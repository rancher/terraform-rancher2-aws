set -x
DIR=$(pwd)
cd ${deploy_path}
pwd
ls -lah
whoami
. envrc
terraform version

TF_CLI_ARGS_init=""
TF_CLI_ARGS_apply=""
if [ -z "${skip_destroy}" ]; then
  timeout -k 1m ${timeout} terraform init -upgrade -reconfigure -no-color
  timeout -k 1m ${timeout} terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate" || true
else
  echo "Not destroying deployed module, it will no longer be managed here."
fi
cd $DIR
exit 0
