#!/usr/bin/env bash

if [ $# -ne 1 ] ; then
     echo "Usage: $0 CLUSTER_NAME"
     exit 1
else
    HDFS_CLUSTER_NAME=$1
fi

kubectl get pvc -l app.kubernetes.io/name=hdfs -l app.kubernetes.io/instance="$HDFS_CLUSTER_NAME"
for pvc in $(kubectl get pvc -l app.kubernetes.io/name=hdfs -l app.kubernetes.io/instance="$HDFS_CLUSTER_NAME" -l app.kubernetes.io/component=journalnode -o name | sed -e 's#persistentvolumeclaim/##'); do
kubectl apply -f - << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-journalnode-${pvc}
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: docker.stackable.tech/stackable/hadoop:3.3.4-stackable23.1.0
          command: ["bash", "-c", "ls -la /stackable/data && if [ -d /stackable/data/journal ]; then echo Removing might existing target dir && rm -rf /stackable/data/journalnode && echo Renaming folder && mv /stackable/data/journal /stackable/data/journalnode; else echo Nothing to do; fi"]
          volumeMounts:
            - name: data
              mountPath: /stackable/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${pvc}
      restartPolicy: Never
  backoffLimit: 1
EOF
done
for pvc in $(kubectl get pvc -l app.kubernetes.io/name=hdfs -l app.kubernetes.io/instance="$HDFS_CLUSTER_NAME" -l app.kubernetes.io/component=namenode -o name | sed -e 's#persistentvolumeclaim/##'); do
kubectl apply -f - << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-namenode-${pvc}
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: docker.stackable.tech/stackable/hadoop:3.3.4-stackable23.1.0
          command: ["bash", "-c", "ls -la /stackable/data && if [ -d /stackable/data/name ]; then echo Removing might existing target dir && rm -rf /stackable/data/namenode && echo Renaming folder && mv /stackable/data/name /stackable/data/namenode; else echo Nothing to do; fi"]
          volumeMounts:
            - name: data
              mountPath: /stackable/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${pvc}
      restartPolicy: Never
  backoffLimit: 1
EOF
done
for pvc in $(kubectl get pvc -l app.kubernetes.io/name=hdfs -l app.kubernetes.io/instance="$HDFS_CLUSTER_NAME" -l app.kubernetes.io/component=datanode -o name | sed -e 's#persistentvolumeclaim/##'); do
kubectl apply -f - << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-datanode-${pvc}
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: docker.stackable.tech/stackable/hadoop:3.3.4-stackable23.1.0
          command: ["bash", "-c", "ls -la /stackable/data/data && if [ -d /stackable/data/data/data ]; then echo Removing might existing target dir && rm -rf /stackable/data/data/datanode && echo Renaming folder && mv /stackable/data/data/data /stackable/data/data/datanode; else echo Nothing to do; fi"]
          volumeMounts:
            - name: data
              mountPath: /stackable/data/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${pvc}
      restartPolicy: Never
  backoffLimit: 1
EOF
done