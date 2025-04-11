#!/bin/bash
set -x

JSONPATH="'{range .items[*]}
  {.metadata.name}{\"\\t\"} \
  {.metadata.namespace}{\"\\t\"} \
  {.status.phase}{\"\\n\"} \
{end}'"

notReady() {
  PODS=$(kubectl get pods -A -o jsonpath="$JSONPATH")
  # shellcheck disable=SC2060,SC2140
  NOT_READY=$(echo "$PODS" | grep -v "Running" | grep -v "Succeeded"  | tr -d ["\t","\n"," ","'"] || true)
  if [ -n "$NOT_READY" ]; then
    # Some pods aren't running
    return 0
  else
    # All pods are running
    return 1
  fi
}

TIMEOUT=10 # 10 minutes
TIMEOUT_MINUTES=$((TIMEOUT * 60))
INTERVAL=30 # 30 seconds
MAX=$((TIMEOUT_MINUTES / INTERVAL))
INDEX=0

while notReady; do
  if [[ $INDEX -lt $MAX ]]; then
    echo "Waiting for pods to be ready..."
    INDEX=$((INDEX + 1))
    sleep $INTERVAL;
  else
    echo "Timeout reached. Pods are not ready..."
    echo "nodes..."
    kubectl get nodes || true
    echo "all..."
    kubectl get all -A || true
    echo "pods..."
    kubectl get pods -A || true
    exit 1
  fi
done

echo "Pods are ready..."

echo "nodes..."
kubectl get nodes || true
echo "all..."
kubectl get all -A || true
echo "pods..."
kubectl get pods -A || true

exit 0
