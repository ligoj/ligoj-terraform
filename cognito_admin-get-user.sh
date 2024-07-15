#!/bin/bash
# ssh_key_generator - designed to work with the Terraform External Data Source provider
#   https://www.terraform.io/docs/providers/external/data_source.html
#  Inpiration https://gist.github.com/irvingpop/968464132ded25a206ced835d50afa6b
#  by Irving Popovetsky <irving@popovetsky.com> 
#

LOG_FILE="cognito_admin-get-user.log"
MESSAGES="[]"
function log_info() {
  local MSG="$1"
  echo "INFO  $MSG" >>"$LOG_FILE"
  MESSAGES="$(echo "$MESSAGES" | jq --arg MSG "$MSG" '. += [$MSG|gsub("^(\\s|\\n)+|(\\s|\\n)+$";"")]')"
}
function error_exit() {
  echo "ERROR: $1" >> "$LOG_FILE"
  echo "$1" 1>&2
  exit 1
}

function check_deps() {
  test -f $(which aws) || error_exit "aws command not detected in path, please install it"
  test -f $(which jq) || error_exit "jq command not detected in path, please install it"
}

function parse_input() {
  # jq reads from stdin so we don't have to set up any inputs, but let's validate the outputs
  eval "$(jq -r '@sh "export USER_POOL_ID=\(.user_pool) PROFILE=\(.profile) USERNAME=\(.username)"')"
  if [[ -z "${USER_POOL_ID}" ]]; then export USER_POOL_ID=none; fi
  if [[ -z "${PROFILE}" ]]; then export PROFILE=none; fi
  if [[ -z "${USERNAME}" ]]; then export USERNAME=none; fi
}

function get_user() {
    log_info "Get cognito user $USERNAME@$USER_POOL_ID (profile=$PROFILE)"
    local result="$(aws cognito-idp admin-get-user --user-pool-id "$USER_POOL_ID" --profile "$PROFILE" --username "$USERNAME" 2>> $LOG_FILE)"
    log_info "$result"
    echo -n "${result}" | jq '{username : .Username}'
}

function main() {
  check_deps
  # echo "DEBUG: received: $INPUT" 1>&2
  parse_input
  get_user
}

main
exit 0