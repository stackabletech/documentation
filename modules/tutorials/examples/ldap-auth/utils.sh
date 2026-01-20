#!/usr/bin/env bash

superset_login() {
  local provider="$1"
  local username="$2"
  local password="$3"

  local request_data
  request_data=$(printf '{"provider": "%s", "username": "%s", "password": "%s", "refresh": false}' "$provider" "$username" "$password")

  local superset_addr
  superset_addr=$(stackablectl svc list -o json | jq --raw-output '.superset| .[0] | .endpoints | .["external-superset"]')
  local superset_endpoint="$superset_addr"/api/v1/security/login

  json_header='Content-Type: application/json'

  echo "Checking if Superset is reachable at $superset_addr"
  return_code=$(curl --insecure -v -o /dev/null -w "%{http_code}" "$superset_addr")
  echo "$return_code"

  local response
  response=$(curl -Ls "$superset_endpoint" -H "$json_header" --data "$request_data")

  if [[ "$response" =~ .*access_token.* ]]; then
    return 0
  fi
  return 1
}