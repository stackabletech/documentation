#!/usr/bin/env bash
set -euo pipefail
shopt -s lastpipe

# Touch the file and trap the delete command for later
touch trino-opa-bundle.yaml
trap 'rm trino-opa-bundle.yaml' EXIT

echo "Fetching Trino OPA Bundle definition from k8s"
# tag::get-yaml[]
kubectl get cm trino-opa-bundle -o yaml > trino-opa-bundle.yaml
# end::get-yaml[]

sleep 2

echo "Updating trino-opa-bundle.yaml in-place with snippet"
yq -i '. *= load("trino-opa-bundle-snippet.yaml")' trino-opa-bundle.yaml

echo "Applying updated configuration"
# tag::apply[]
kubectl apply -f trino-opa-bundle.yaml
# end::apply[]

sleep 2