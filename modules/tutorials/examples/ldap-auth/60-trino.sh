#!/usr/bin/env bash
set -euo pipefail

echo "Applying Trino cluster"
# tag::apply-trino[]
kubectl apply -f trino.yaml
# end::apply-trino[]
