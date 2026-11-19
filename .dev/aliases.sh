#!/usr/bin/env bash
#
# Helper: aliases.sh
# Description: Standard shell aliases for development workflow.

# shellcheck disable=SC2142
alias gs='git status'
alias gd='git diff'
alias gc='git checkout'
alias tf='terraform'
alias tfa='terraform apply --auto-approve'
alias tfd='terraform destroy --auto-approve'
alias k='kubectl'
alias sc='shell_check'
