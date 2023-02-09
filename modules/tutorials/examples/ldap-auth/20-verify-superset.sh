#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

source "./utils.sh"

# wait for superset resource to appear
sleep 3

echo "Waiting for superset StatefulSet ..."
kubectl rollout status --watch statefulset/superset-node-default

sleep 5

echo "Checking if login is working correctly ..."

username="admin"
password="adminadmin"

if superset_login "db" "$username" "$password"; then
  echo "Login successful with $username:$password"
else
  echo "Login not successful. Exiting."
  exit 1
fi

username="admin"
password="wrongpassword"

if ! superset_login "db" "$username" "$password"; then
  echo "Login un-successful with $username:$password as expected"
else
  echo "Login with $username:$password successful but should not be! Exiting."
  exit 1
fi

echo "Login is working correctly"
