#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

source "./utils.sh"

echo "Creating credentials secret"
# tag::apply-superset-credentials[]
kubectl apply -f superset-credentials.yaml
# end::apply-superset-credentials[]

ln -s superset/superset-no-ldap.yaml superset.yaml
echo "Creating Superset cluster"
# tag::apply-superset-cluster[]
kubectl apply -f superset.yaml
# end::apply-superset-cluster[]
rm superset.yaml

echo "Waiting on SupersetDB ..."
# tag::wait-supersetdb[]
kubectl wait supersetdb/superset \
  --for jsonpath='{.status.condition}'=Ready \
  --timeout 300s
# end::wait-supersetdb[]

sleep 5

echo "Wainting on superset StatefulSet ..."
kubectl rollout status --watch statefulset/superset-node-default

sleep 5

username="admin"
password="admin"

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

echo "Deleting superset"
# tag::delete-superset[]
#kubectl delete superset superset
# end::delete-superset[]
