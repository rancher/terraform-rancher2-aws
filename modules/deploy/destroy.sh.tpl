#!/usr/bin/env sh
DIR=$(pwd)

# Add ~/bin to PATH for age and aws
export PATH="$${HOME}/bin:$PATH"

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
cd "${deploy_path}" || { echo "Failed to change directory to ${deploy_path}"; exit 1; }

if [ -f ./envrc ]; then
  # shellcheck disable=SC1091
  . ./envrc
else
  echo "can't find envrc..."
  if [ "$SECRETS_DECRYPTED" = "1" ] && [ -f "$DECRYPTED_SECRETS" ]; then rm -f "$DECRYPTED_SECRETS"; fi
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

# shellcheck disable=SC2034
TF_CLI_ARGS_init=""
# shellcheck disable=SC2034
TF_CLI_ARGS_apply=""

# shellcheck disable=SC2154
if [ -z "${skip_destroy}" ]; then
  # shellcheck disable=SC2154
  timeout -k 1m "${timeout}" terraform init -no-color

  # shellcheck disable=SC2154
  timeout -k 1m "${timeout}" terraform destroy -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate" || true
else
  echo "Not destroying deployed module, it will no longer be managed here."
fi

# Cleanup decrypted secrets
if [ "$SECRETS_DECRYPTED" = "1" ] && [ -f "$DECRYPTED_SECRETS" ]; then
  rm -f "$DECRYPTED_SECRETS"
fi

cd "$DIR" || exit 1
exit 0
