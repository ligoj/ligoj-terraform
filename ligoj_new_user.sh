#!/bin/bash
# ssh_key_generator - designed to work with the Terraform External Data Source provider
#   https://www.terraform.io/docs/providers/external/data_source.html
#  Inpiration: https://gist.github.com/irvingpop/968464132ded25a206ced835d50afa6b
#  by Irving Popovetsky <irving@popovetsky.com>
#

MESSAGES="[]"
LOG_FILE="ligoj_new_user.log"
USE_DATA_API="0"
ROLE_ADMIN="ADMIN"
function log_info() {
  local MSG="$1"
  echo "INFO  $MSG" >>"$LOG_FILE"
  MESSAGES="$(echo "$MESSAGES" | jq --arg MSG "$MSG" '. += [$MSG|gsub("^(\\s|\\n)+|(\\s|\\n)+$";"")]')"
}
function error_exit() {
  local MSG="$1"
  echo "ERROR $MSG" >>"$LOG_FILE"
  echo "$MSG" 1>&2
  exit 1
}

function check_deps() {
  test -f $(which aws) || error_exit "aws command not detected in path, please install it"
  test -f $(which jq) || error_exit "jq command not detected in path, please install it"
  if [ "$USE_DATA_API" != "1" ]; then
    test -f $(which mysql) || error_exit "mysql command not detected in path, please install it"
  fi
}

function parse_input() {
  # jq reads from stdin so we don't have to set up any inputs, but let's validate the outputs
  eval "$(jq -r '@sh "export RDS_ARN=\(.rds_arn) FUNCTION_NAME=\(.function_name) RDS_SECRET_ARN=\(.rds_secret_arn) RDS_SECRET_64=\(.rds_secret_64) PROFILE=\(.profile) REGION=\(.region) USERNAME=\(.username) POOL_ID=\(.user_pool) DATABASE=\(.database) API_TOKEN_NAME=\(.api_token_name) API_TOKEN=\(.api_token)"')"
  if [[ -z "${RDS_ARN}" ]]; then export RDS_ARN=none; fi
  if [[ -z "${FUNCTION_NAME}" ]]; then export FUNCTION_NAME=none; fi
  if [[ -z "${RDS_SECRET_ARN}" ]]; then export RDS_SECRET_ARN=none; fi
  if [[ -z "${RDS_SECRET_64}" ]]; then export RDS_SECRET_64=none; fi
  if [[ -z "${PROFILE}" ]]; then export PROFILE=none; fi
  if [[ -z "${REGION}" ]]; then export REGION=none; fi
  if [[ -z "${USERNAME}" ]]; then export USERNAME=none; fi
  if [[ -z "${POOL_ID}" ]]; then export POOL_ID=none; fi
  if [[ -z "${DATABASE}" ]]; then export DATABASE=none; fi
  if [[ -z "${API_TOKEN_NAME}" ]]; then export API_TOKEN_NAME=none; fi
  if [[ -z "${API_TOKEN}" ]]; then export API_TOKEN=none; fi
  LOG_FILE="ligoj_new_user-${USERNAME}.log"
}

function execute_sql() {
  set +e
  local SQL="$1"
  local waitMax=10
  while true; do
    local result=""
    if [ "$USE_DATA_API" == "1" ]; then
      log_info "aws rds-data execute-statement --region $REGION --database $DATABASE --resource-arn $RDS_ARN --secret-arn $RDS_SECRET_ARN --profile $PROFILE"
      result="$(aws rds-data execute-statement --region "$REGION" --database "$DATABASE" --resource-arn "$RDS_ARN" --secret-arn "$RDS_SECRET_ARN" --profile "$PROFILE" --sql "${SQL:Q}" 2>&1)"
    else
      local encoded_sql="$(echo "$SQL" | base64)"
      local encoded_payload="$(echo '{ 
        "database": "'$DATABASE'",
        "query": "'$encoded_sql'", 
        "secret": "'$RDS_SECRET_64'"
      }'| base64)"
      log_info "$SQL"
      rm -f "ligoj_new_user-invoke-payload.log"
      result="$(aws lambda invoke --region $REGION --profile $PROFILE --function-name $FUNCTION_NAME --payload "$encoded_payload" "ligoj_new_user-invoke-payload.log")"
    fi
    if [ "$?" == "0" -a "$result" != "" ]; then
      if [ "$USE_DATA_API" == "1" ]; then
        log_info "Succeed: $result"
      elif [ -f "ligoj_new_user-invoke-payload.log" ]; then
        cat "ligoj_new_user-invoke-payload.log" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        result="$(cat "ligoj_new_user-invoke-payload.log")"
        rm -f "ligoj_new_user-invoke-payload.log"
      fi
      break
    fi
    log_info "Retrying: $result"
    if [ -f "ligoj_new_user-invoke-payload.log" ]; then
      cat "ligoj_new_user-invoke-payload.log" >> "$LOG_FILE"
      echo "" >> "$LOG_FILE"
      rm -f "ligoj_new_user-invoke-payload.log"
    fi
    sleep 5
    waitMax=$(($waitMax - 1))
    if [[ "$waitMax" == "0" ]]; then
      set -e
      log_info "ERROR: No result after many tries"
      exit 2
    fi
  done
  set -e
  echo -n "$result"
}

function next_id() {
  local TABLE="$1"
  local next_id="$(select_from "SELECT next_val as id FROM ${TABLE}_seq" "Unable to get the next id of $TABLE table")"
  increment_next_id "$TABLE"
  echo "$next_id"
}

function increment_next_id() {
  local TABLE="$1"
  local result="$(execute_sql "UPDATE ${TABLE}_seq SET next_val=next_val+1")"
  local inserted="$(echo "$result" | jq -r '.affectedRows')"
  if [ "$inserted" != "1" ]; then
    error_exit "Unable to get the next id of $TABLE table, -$inserted- affected rows instead of 1"
    exit 1
  fi
}

function insert() {
  local SQL="$1"
  local error="$2"
  local result="$(execute_sql "$SQL")"
  local inserted="$(echo "$result" | jq -r '.affectedRows')"
  if [ "$inserted" != "1" ]; then
    error_exit "$error, -$inserted- affected rows instead of 1: $result"
    exit 1
  fi
}

function select_from() {
  local SQL="$1"
  local error="$2"
  local result="$(execute_sql "$SQL")"
  local id="$(echo "$result" | jq -r '.records[0].id')"
  if [ "$id" == "null" ]; then
    error_exit "$error: $result"
    exit 1
  fi
  echo "$id"
}

function create_user() {

  # Check user
  log_info "Check user $USERNAME exists..."
  local result="$(execute_sql "SELECT 1 FROM s_user WHERE login = \"$USERNAME\"")"
  local user_exists="$(echo "$result" | jq -r '.records|length')"

  # Create user as needed
  if [ "$user_exists" == "1" ]; then
    log_info "User $USERNAME exists"
  else
    log_info "User $USERNAME does not exist"
    insert "INSERT INTO s_user (login) VALUES (\"$USERNAME\")" "Unable to create user $USERNAME"
  fi

  # Check role
  log_info "Check role $ROLE_ADMIN..."
  local role_id="$(select_from 'SELECT id FROM s_role WHERE name = "'$ROLE_ADMIN'"' 'Role '$ROLE_ADMIN' does not exist yet')"

  # Associate ADMIN role
  log_info "Check role assignment for $ROLE_ADMIN role ($role_id) and user $USERNAME ..."
  result="$(execute_sql "SELECT 1 FROM s_role_assignment WHERE user = \"$USERNAME\" AND role = $role_id")"
  local assignment_exists="$(echo "$result" | jq -r '.records|length')"
  if [ "$assignment_exists" == "1" ]; then
    log_info "Role $ROLE_ADMIN already assigned to user $USERNAME"
  else
    log_info "Get next role assignment id for $ROLE_ADMIN role ($role_id) and user $USERNAME ..."
    local next_assignment_id="$(next_id s_role_assignment)"
    log_info "Create role assignment ($next_assignment_id) for $ROLE_ADMIN role ($role_id) and user $USERNAME ..."
    insert "INSERT INTO s_role_assignment (id, role, user) VALUES ($next_assignment_id, $role_id,\"$USERNAME\")" "Unable to associate user $USERNAME to $ROLE_ADMIN role ($role_id)"
  fi

  # Create API KEY
  log_info "Check API key $API_TOKEN_NAME of user $USERNAME ..."
  result="$(execute_sql "SELECT 1 AS id FROM s_api_token WHERE name = \"$API_TOKEN_NAME\" AND user = \"$USERNAME\"")"
  local token_exists="$(echo "$result" | jq -r '.records|length')"
  if [ "$token_exists" == "1" ]; then
    log_info "API key $API_TOKEN_NAME of user $USERNAME already exist with value $(echo "$result" | jq -r '.records[0].id')"
  else
    log_info "Get next API key id for user $USERNAME ..."
    # Reserve the sequence
    local next_api_id="$(next_id s_api_token)"
    # Create the token
    log_info "Create API key ($next_api_id) for user $USERNAME and named $API_TOKEN_NAME ..."
    insert "INSERT INTO s_api_token (id, name, user, token, hash) VALUES ($next_api_id, \"$API_TOKEN_NAME\",\"$USERNAME\",\"$API_TOKEN\", \"_plain_\")" "Unable to create a token $API_TOKEN_NAME for user $USERNAME"
    # Return the given token
    log_info "Created API key $API_TOKEN_NAME to user $USERNAME with value $API_TOKEN"
  fi
  echo '{}' | jq -r --arg API_TOKEN_NAME "$API_TOKEN_NAME" --arg API_TOKEN "$API_TOKEN" --argjson MESSAGES "$MESSAGES" '
        {api_token:$API_TOKEN, message: $MESSAGES[0],api_token_name:$API_TOKEN_NAME}'
}

function main() {
  rm -f $LOG_FILE
  check_deps
  parse_input
  rm -f $LOG_FILE
  create_user
}

{ # try
  main
  #save your output
} || { # catch
  echo "Command failed: $MESSAGES"
  exit 1
}
