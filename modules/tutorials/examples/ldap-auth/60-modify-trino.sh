#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

# Touch the file and trap the delete command for later
touch trino.yaml
trap 'rm trino.yaml' EXIT

echo "Fetching TrinoCluster definition from k8s"
# tag::get-yaml[]
kubectl get trino trino -o yaml > trino.yaml
# end::get-yaml[]

echo "Deleting TrinoCluster"
# tag::delete[]
kubectl delete trino trino
# end::delete[]

echo "Waiting for deletion to complete ..."
kubectl wait --for=delete statefulset/trino-coordinator-default --timeout=60s
kubectl wait --for=delete statefulset/trino-worker-default --timeout=60s

sleep 2

echo "Updating superset.yaml in-place with authentication LDAP snippet"
yq -i 'del(.spec.authentication.method.multiUser)' trino.yaml
yq -i '. *= load("trino-auth-snippet.yaml")' trino.yaml

echo "Applying updated configuration"
# tag::apply[]
kubectl apply -f trino.yaml
# end::apply[]

echo "Waiting for Trino StatefulSets rollout ..."
kubectl rollout status --watch statefulset/trino-coordinator-default
kubectl rollout status --watch statefulset/trino-worker-default

sleep 2
