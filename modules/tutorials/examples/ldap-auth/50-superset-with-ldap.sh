#!/usr/bin/env bash
set -euo pipefail

ln -s superset/superset-yes-ldap.yaml superset.yaml
echo "Updating Superset cluster definition"
# tag::apply-superset-cluster[]
kubectl apply -f superset.yaml
# end::apply-superset-cluster[]
rm superset.yaml

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
