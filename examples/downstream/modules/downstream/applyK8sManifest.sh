#!/bin/bash

# this script is called like this:
# ./applyK8sManifest.sh <<EOF
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: "config"
#   namespace: "kube-system"
#   annotations:
#     rke.cattle.io/object-authorized-for-clusters: cluster-name
# data:
#   "config": ""
# EOF


TMPFILE=$(mktemp)
cat > "$TMPFILE"
if [ -z "$(cat "$TMPFILE")" ]; then echo "no contents supplied, failing..."; exit 1; fi

kubectl apply -f "$TMPFILE"

rm -f "$TMPFILE"
