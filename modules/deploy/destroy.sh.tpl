#!/usr/bin/env sh
set -x
DIR=$(pwd)
# shellcheck disable=SC2154
cd "${deploy_path}" || exit 1
pwd
ls -lah
whoami
if [ -f ./envrc ]; then
  # shellcheck disable=SC1091
  . ./envrc
else
  echo "can't find envrc..."
  exit 1
fi
terraform version

# shellcheck disable=SC2034
TF_CLI_ARGS_init=""
# shellcheck disable=SC2034
TF_CLI_ARGS_apply=""

# shellcheck disable=SC2154
if [ -z "${skip_destroy}" ]; then
  # shellcheck disable=SC2154
  timeout -k 1m "${timeout}" terraform init -upgrade -reconfigure -no-color
  # shellcheck disable=SC2154
  timeout -k 1m "${timeout}" terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate" || true
else
  echo "Not destroying deployed module, it will no longer be managed here."
fi
cd "$DIR" || exit 1
exit 0
