#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

source "./utils.sh"

# wait for superset resource to appear
for (( i=1; i<=30; i++ ))
do
  echo "Waiting for superset StatefulSet to appear ..."
  if eval kubectl get statefulset superset-node-default; then
    break
  fi

  sleep 3
done

echo "Waiting for superset StatefulSet to become ready ..."
kubectl rollout status --watch --timeout=5m statefulset/superset-node-default

sleep 5

echo "Stackable services:"

stackablectl svc list

echo "Checking if login is working correctly ..."

username="admin"
password="adminadmin"

if superset_login "db" "$username" "$password"; then
  echo "Login successful with $username:$password"
else
  echo "Login not successful. Exiting."
  exit 1
fi

echo "11111111111111111111111111111111111111111"
sleep 300

if superset_login "db" "$username" "$password"; then
  echo "Login successful with $username:$password"
else
  echo "Login not successful. Exiting."
  exit 1
fi

echo "2222222222222222222222222222222222222222222"
sleep 300

if superset_login "db" "$username" "$password"; then
  echo "Login successful with $username:$password"
else
  echo "Login not successful. Exiting."
  exit 1
fi

echo "33333333333333333333333333333333"
sleep 300

if superset_login "db" "$username" "$password"; then
  echo "Login successful with $username:$password"
else
  echo "Login not successful. Exiting."
  exit 1
fi

echo "FINISHED FINISHED FINISHED FINISHED"
sleep 30000


username="admin"
password="wrongpassword"

if ! superset_login "db" "$username" "$password"; then
  echo "Login un-successful with $username:$password as expected"
else
  echo "Login with $username:$password successful but should not be! Exiting."
  exit 1
fi

echo "Login is working correctly"
