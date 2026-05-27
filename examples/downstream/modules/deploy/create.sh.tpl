#!/usr/bin/env sh
DIR=$(pwd)

CREATE_AFTER_PERSIST=$1

# Add ~/bin to PATH for age and aws
export PATH="$HOME/bin:$PATH"

# shellcheck disable=SC2329
cleanup() {
  echo "Script interrupted. Cleaning up..."
  if [ "$SECRETS_DECRYPTED" = "1" ] && [ -n "$DECRYPTED_SECRETS" ] && [ -f "$DECRYPTED_SECRETS" ]; then
    rm -f "$DECRYPTED_SECRETS"
  fi
  exit 1
}
trap 'cleanup' INT TERM

# Handle age decryption if needed
SECRETS_DECRYPTED=0
if [ -n "$AGE_KEY_PATH" ] && [ -n "$SECRETS_PATH" ] && [ -f "$AGE_KEY_PATH" ] && [ -f "$SECRETS_PATH" ]; then
  DECRYPTED_SECRETS=$(mktemp /tmp/secrets.XXXXXX)
  echo "Decrypting secrets with age..."

  if age -d -i "$AGE_KEY_PATH" -o "$DECRYPTED_SECRETS" "$SECRETS_PATH"; then
    chmod 0600 "$DECRYPTED_SECRETS"
    # shellcheck disable=SC1090
    . "$DECRYPTED_SECRETS"
    SECRETS_DECRYPTED=1
  else
    echo "Failed to decrypt secrets"
    exit 1
  fi
else
  echo "No secrets to decrypt"
fi

# shellcheck disable=SC2154
cd "${deploy_path}" || exit
if [ -f ./envrc ]; then
  # shellcheck disable=SC1091
  . ./envrc
else
  echo "can't find envrc..."
  if [ $SECRETS_DECRYPTED -eq 1 ]; then rm -f "$DECRYPTED_SECRETS"; fi
  exit 1
fi

# Set up plugin cache directory
# shellcheck disable=SC2154
if [ ! -d "${plugin_cache}" ]; then
  install -d "${plugin_cache}"
fi
if [ -n "$TF_PLUGIN_CACHE_DIR" ]; then
    # shellcheck disable=SC2154
    cp -a "$TF_PLUGIN_CACHE_DIR/." "${plugin_cache}/" 2>/dev/null || true
fi
# shellcheck disable=SC2154
export TF_PLUGIN_CACHE_DIR="${plugin_cache}"

echo "Plugin cache directory: $TF_PLUGIN_CACHE_DIR"

export TF_IN_AUTOMATION=1

terraform version

if [ -z "$CREATE_AFTER_PERSIST" ]; then
  # shellcheck disable=SC2154
  ${init_script}
fi
if [ ! -f '.terraform.lock.hcl' ]; then
  # even if we are running create after persist,
  # if the lock file doesn't exist we need to run init
  # shellcheck disable=SC2154
  ${init_script}
fi

# shellcheck disable=SC2034
TF_CLI_ARGS_init=""
# shellcheck disable=SC2034
TF_CLI_ARGS_apply=""

# shellcheck disable=SC2154
max_attempts=${attempts}
final_exit_code=1
overall_attempt=0

while [ $final_exit_code -gt 0 ] && [ $overall_attempt -lt "$max_attempts" ]; do
  apply_attempt=0
  apply_exit_code=1
  destroy_exit_code=0

  while [ $apply_exit_code -gt 0 ] && [ $apply_attempt -lt "$max_attempts" ]; do
    # shellcheck disable=SC2154
    timeout -k 1m "${timeout}" terraform apply -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
    apply_exit_code=$?

    if [ $apply_exit_code -eq 124 ]; then echo "Apply timed out after ${timeout}"; fi
    apply_attempt=$((apply_attempt + 1))
  done

  # Don't destroy if the overall final attempt fails
  if [ $apply_exit_code -gt 0 ] && [ "$overall_attempt" -ne "$((max_attempts - 1))" ]; then
    destroy_attempt=0
    destroy_exit_code=1

    while [ $destroy_exit_code -gt 0 ] && [ $destroy_attempt -lt "$max_attempts" ]; do
      # shellcheck disable=SC2154
      timeout -k 1m "${timeout}" terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
      destroy_exit_code=$?

      if [ $destroy_exit_code -eq 124 ]; then echo "Destroy timed out after ${timeout}"; fi
      destroy_attempt=$((destroy_attempt + 1))
    done
  fi

  if [ $apply_exit_code -gt 0 ]; then
    echo "Apply failed."
  fi
  if [ $destroy_exit_code -gt 0 ]; then
    echo "Destroy failed."
  fi

  if [ $apply_exit_code -gt 0 ] || [ $destroy_exit_code -gt 0 ]; then
    final_exit_code=1
  else
    final_exit_code=0
  fi

  overall_attempt=$((overall_attempt + 1))

  if [ $final_exit_code -gt 0 ] && [ $overall_attempt -lt "$max_attempts" ]; then
    # shellcheck disable=SC2154
    echo "Waiting ${interval} seconds before next attempt..."
    # shellcheck disable=SC2154
    sleep "${interval}"
  fi
done

if [ $overall_attempt -eq "$max_attempts" ]; then echo "Max attempts reached."; fi
if [ $final_exit_code -ne 0 ]; then echo "Failure, exit code $final_exit_code."; fi
if [ $final_exit_code -eq 0 ]; then
  echo "Success!"
  # shellcheck disable=SC2154
  terraform output -json -state="tfstate" > "outputs.json"
  if [ -f "outputs.json" ]; then
    echo "outputs successfully created"
  else
    echo "outputs failed to be created"
    echo "{}" > "outputs.json"
    final_exit_code=1
  fi
else
  echo "Failure, exit code $final_exit_code."
fi

# Cleanup decrypted secrets
if [ $SECRETS_DECRYPTED -eq 1 ] && [ -f "$DECRYPTED_SECRETS" ]; then
  rm -f "$DECRYPTED_SECRETS"
fi

cd "$DIR" || exit
exit $final_exit_code
