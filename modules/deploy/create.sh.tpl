#!/usr/bin/env sh
set -x
DIR=$(pwd)
# shellcheck disable=SC2154
cd "${deploy_path}" || exit
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
${init_script}

# shellcheck disable=SC2154
MAX=${attempts}
EXITCODE=1
ATTEMPTS=0
E=1
E1=0
while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt "$MAX" ]; do
  A=0
  while [ $E -gt 0 ] && [ $A -lt "$MAX" ]; do
    # shellcheck disable=SC2154
    timeout -k 1m "${timeout}" terraform apply -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
    E=$?
    if [ $E -eq 124 ]; then echo "Apply timed out after ${timeout}"; fi
    A=$((A+1))
  done
  # don't destroy if the last attempt fails
  if [ $E -gt 0 ] && [ $ATTEMPTS != $((MAX-1)) ]; then
    A1=0
    while [ $E1 -gt 0 ] && [ $A1 -lt "$MAX" ]; do
      timeout -k 1m "${timeout}" terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
      E1=$?
      if [ $E1 -eq 124 ]; then echo "Apply timed out after ${timeout}"; fi
      A1=$((A1+1))
    done
  fi
  if [ $E -gt 0 ]; then
    echo "apply failed..."
  fi
  if [ $E1 -gt 0 ]; then
    echo "destroy failed..."
  fi
  if [ $E -gt 0 ] || [ $E1 -gt 0 ]; then
    EXITCODE=1
  else
    EXITCODE=0
  fi
  ATTEMPTS=$((ATTEMPTS+1))
  if [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt "$MAX" ]; then
    # shellcheck disable=SC2154
    echo "wait ${interval} seconds between attempts..."
    # shellcheck disable=SC2154
    sleep "${interval}"
  fi
done
if [ $ATTEMPTS -eq "$MAX" ]; then echo "max attempts reached..."; fi
if [ $EXITCODE -ne 0 ]; then echo "failure, exit code $EXITCODE..."; fi
if [ $EXITCODE -eq 0 ]; then
  echo "success...";
  terraform output -json -state="tfstate" > outputs.json
fi
cd "$DIR" || exit
exit $EXITCODE
