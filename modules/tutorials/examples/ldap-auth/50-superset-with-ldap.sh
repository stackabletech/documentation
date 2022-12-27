#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

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

# get superset endpoint from stackablectl
superset_endpoint=$(stackablectl svc list -o json | jq --raw-output '.superset| .[0] | .endpoints | .["external-superset"]')

# init cookie jar
cookie_jar=cookies.tmp
touch $cookie_jar
trap "rm $cookie_jar" EXIT

# request cookie
curl -Ls --cookie-jar $cookie_jar --output /dev/null $superset_endpoint

# attempt login
curl -Ls --cookie-jar $cookie_jar --output /dev/null $superset_endpoint/login \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data "username=alice&password=alice" \
  --write-out "%{url_effective}\n" | read final_url

echo "curl redirected to: $final_url, should be welcome, not login"
