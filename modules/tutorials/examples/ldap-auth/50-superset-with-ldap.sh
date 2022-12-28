#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

source "./utils.sh"

ln -s superset/superset-yes-ldap.yaml superset.yaml
echo "Updating Superset cluster definition"
# tag::apply-superset-cluster[]
kubectl apply -f superset.yaml
# end::apply-superset-cluster[]
rm superset.yaml

sleep 2

echo "Wainting on superset StatefulSet ..."
kubectl rollout status --watch statefulset/superset-node-default

sleep 2

username="admin"
password="admin"

if superset_login "db" "$username" "$password"; then
  echo "Login with DB admin user succeeded but should not have. Exiting."
  exit 1
else
  echo "Login now un-successful with $username:$password and provider 'db'"
fi

username="alice"
password="alice"

if superset_login "ldap" "$username" "$password"; then
  echo "Login with LDAP $username:$password successful"
else
  echo "Login with LDAP $username:$password unsuccessful. Exiting."
  exit 1
fi