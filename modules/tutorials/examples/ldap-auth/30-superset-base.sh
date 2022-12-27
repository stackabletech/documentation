#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

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

# get superset endpoint from stackablectl
superset_endpoint=$(stackablectl svc list -o json | jq --raw-output '.superset| .[0] | .endpoints | .["external-superset"]')

# init cookie jar
cookie_jar=cookies.tmp
touch $cookie_jar
#trap "rm $cookie_jar" EXIT

curl -Ls --cookie-jar $cookie_jar --output /dev/null $superset_endpoint
curl -Ls --cookie-jar $cookie_jar --output /dev/null $superset_endpoint/login \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data "username=admin&password=admin" \
  --write-out "%{url_effective}\n" | read final_url

echo "curl redirected to: $final_url, should be welcome, not login"

# TODO
# The curl login check doesn't work yet

echo "Deleting superset"
# tag::delete-superset[]
kubectl delete superset superset
# end::delete-superset[]
