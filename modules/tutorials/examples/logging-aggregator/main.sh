#!/usr/bin/env bash

echo "Installing ZooKeeper Operator"
# tag::zk-op[]
stackablectl release install -i secret -i commons -i listener -i zookeeper 23.11
# end::zk-op[]

# tag::vector-agg[]
helm install \
  --wait \
  --values vector-aggregator-values.yaml \
  vector-aggregator vector/vector
# end::vector-agg[]

# tag::vector-discovery[]
kubectl apply --f vector-aggregator-discovery.yaml
# end::vector-discovery[]

# tag::zk[]
kubectl apply -f zookeeper.yaml
# end::zk[]

# Wait until the zookeeper-operator deployed the StatefulSet
kubectl wait \
  --for=condition=available \
  --timeout=5m \
  zookeeperclusters.zookeeper.stackable.tech/simple-zk

# tag::grep[]
kubectl logs vector-aggregator-0 | grep "zookeeper.version=" | jq
# end::grep[]

if [ "${PIPESTATUS[1]}" -eq 0 ]
then
  echo "it worked"
else
  echo "it didn't work"
fi