#!/usr/bin/env bash

echo "Installing ZooKeeper Operator"
# tag::zk-op[]
stackablectl release install -i secret -i commons -i zookeeper 23.7
# end::zk-op[]

# tag::vector-agg[]
helm install -f vector-aggregator-values.yaml vector-aggregator vector/vector
# end::vector-agg[]

# tag::vector-discovery[]
kubectl apply -f vector-aggregator-discovery.yaml
# end::vector-discovery[]

# tag::zk[]
kubectl apply -f zookeeper.yaml
# end::zk[]

# TODO make this somehow a testable thing
# maybe get the logs from the agg. and grep for a specific line?

# tag::grep[]
kubectl logs vector-aggregator-0 | grep "zookeeper.version="
# end::grep[]

if [ "$?" -eq 0 ]
then
    echo "it worked"
else
    echo "it didn't work :("
fi