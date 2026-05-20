#!/bin/bash

JSONPATH="'{range .items[*]}
  {.metadata.name}{\"\\t\"} \
  {.metadata.namespace}{\"\\t\"} \
  {.status.readyReplicas}{\"\\t\"} \
  {.status.replicas}{\"\\n\"} \
{end}'"

notReady() {
  if ! ITEMS=$(kubectl get deployments -A -o jsonpath="$JSONPATH"); then
    # The cluster is not ready if kubectl fails
    return 0
  fi

  ITEMS=$(echo "$ITEMS" | tr -d "'")
  if [ -z "$(echo "$ITEMS" | tr -d ' \t\n\r')" ]; then
    # The cluster is not ready if no deployments are found
    return 0
  fi

  NOT_READY=$(echo "$ITEMS" | awk '{
    if (NF == 0) next;
    if ($3 != $4) {
      print 1;
      exit;
    }
  }')
  if [ -n "$NOT_READY" ]; then
    # Some items aren't ready
    return 0
  else
    # All items are ready
    return 1
  fi
}

readyWait() {
  TIMEOUT=3 # 3 minutes
  TIMEOUT_MINUTES=$((TIMEOUT * 60))
  INTERVAL=30 # 30 seconds
  MAX=$((TIMEOUT_MINUTES / INTERVAL)) # defaults to 6
  ATTEMPTS=0

  while notReady; do
    if [ "$ATTEMPTS" -lt "$MAX" ]; then
      ATTEMPTS=$((ATTEMPTS + 1))
      sleep "$INTERVAL";
    else
      return 1
    fi
  done
  return 0
}

SUCCESSES=0
SUCCESSES_NEEDED=2

while readyWait && [ "$SUCCESSES" -lt "$SUCCESSES_NEEDED" ]; do
  SUCCESSES=$((SUCCESSES + 1))
  echo "succeeeded $SUCCESSES times..."
  sleep 30
done

if [ "$SUCCESSES" -eq "$SUCCESSES_NEEDED" ]; then
  echo "$SUCCESSES_NEEDED successes reached, passed..."
  EXITCODE=0
else
  echo "$SUCCESSES_NEEDED successes not reached, failed..."
  EXITCODE=1
fi

echo "nodes..."
kubectl get nodes || true

echo "all..."
kubectl get all -A || true

echo "deployments..."
kubectl get deployments -A || true

if [ "$EXITCODE" -ne 0 ]; then
  echo "Troubleshooting information for deployments that are not ready..."
  ITEMS=$(kubectl get deployments -A -o jsonpath="$JSONPATH")
  echo "$ITEMS" | tr -d "'" | awk '{
    if (NF == 0) next;
    if ($3 != $4) {
      print $1, $2;
    }
  }' | while read -r DEPLOYMENT_NAME NAMESPACE; do
    if [ -n "$DEPLOYMENT_NAME" ] && [ -n "$NAMESPACE" ]; then
      echo "=================================================="
      echo "Describing deployment $DEPLOYMENT_NAME in namespace $NAMESPACE..."
      kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" || true
      echo "--------------------------------------------------"
      echo "Logs for deployment $DEPLOYMENT_NAME in namespace $NAMESPACE..."
      kubectl logs "deployment/$DEPLOYMENT_NAME" -n "$NAMESPACE" --all-containers --tail=100 || true
    fi
  done
fi

exit $EXITCODE
