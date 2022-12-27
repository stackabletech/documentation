#!/usr/bin/env bash
set -euo pipefail

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

echo "Starting port-forwarding of port 8088"
# tag::port-forwarding[]
kubectl port-forward service/superset-external 8088 2>&1 >/dev/null &
# end::port-forwarding[]
PORT_FORWARD_PID=$!
trap "kill $PORT_FORWARD_PID" EXIT
sleep 5

echo "Checking if web interface is reachable ..."
return_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8088/login/)
if [ "$return_code" == 200 ]; then
  echo "Web interface reachable!"
else
  echo "Could not reach web interface."
  exit 1
fi
