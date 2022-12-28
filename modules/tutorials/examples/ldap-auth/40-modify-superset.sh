#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

# Touch the file and trap the delete command for later
touch superset.yaml
trap 'rm superset.yaml' EXIT

echo "Fetching SupersetCluster definition from k8s"
# tag::get-superset-yaml[]
kubectl get superset superset -o yaml > superset.yaml
# end::get-superset-yaml[]

echo "Deleting SupersetCluster"
# tag::delete-superset[]
kubectl delete superset superset
# end::delete-superset[]

echo "Waiting on deletion to complete ..."
kubectl wait --for=delete statefulset/superset-node-default --timeout=60s


sleep 10

echo "Updating superset.yaml in-place with authentication LDAP snippet"
yq -i '. *= load("superset-auth-snippet.yaml")' superset.yaml

echo "Applying updated configuration"
# tag::apply-superset-cluster[]
kubectl apply -f superset.yaml
# end::apply-superset-cluster[]

sleep 2

echo "Waiting on superset StatefulSet ..."
kubectl rollout status --watch statefulset/superset-node-default

sleep 2

