cd ${deploy_path}
. envrc
TF_CLI_ARGS_init=""
TF_CLI_ARGS_apply=""

${init_script}

MAX=${attempts}
EXITCODE=1
ATTEMPTS=0
E=1
E1=0
while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; do
  A=0
  while [ $E -gt 0 ] && [ $A -lt $MAX ]; do
    timeout -k 1m ${timeout} terraform apply -var-file="${deploy_path}/inputs.tfvars" -auto-approve -state="${deploy_path}/tfstate"
    E=$?
    if [ $E -eq 124 ]; then echo "Apply timed out after ${timeout}"; fi
    A=$((A+1))
  done
  # don't destroy if the last attempt fails
  if [ $E -gt 0 ] && [ $ATTEMPTS != $((MAX-1)) ]; then
    A1=0
    while [ $E1 -gt 0 ] && [ $A1 -lt $MAX ]; do
      timeout -k 1m ${timeout} terraform destroy -var-file="${deploy_path}/inputs.tfvars" -auto-approve -state="${deploy_path}/tfstate"
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
  if [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt $MAX ]; then
    echo "wait ${interval} seconds between attempts..."
    sleep ${interval}
  fi
done
if [ $ATTEMPTS -eq $MAX ]; then echo "max attempts reached..."; fi
if [ $EXITCODE -ne 0 ]; then echo "failure, exit code $EXITCODE..."; fi
if [ $EXITCODE -eq 0 ]; then
  echo "success...";
  terraform output -json -state="${deploy_path}/tfstate" > ${deploy_path}/outputs.json
fi
exit $EXITCODE
