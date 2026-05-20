#!/bin/bash

JSONPATH="'{range .items[*]}
  {.metadata.name}{\"\\t\"} \
  {.metadata.namespace}{\"\\t\"} \
  {.status.phase}{\"\\t\"} \
  {.status.conditions[?(@.type==\"Ready\")].status}{\"\\n\"} \
{end}'"

notReady() {
  if ! PODS=$(kubectl get pods -A -o jsonpath="$JSONPATH"); then
    # The cluster is not ready if kubectl fails
    return 0
  fi

  PODS=$(echo "$PODS" | tr -d "'")
  if [ -z "$(echo "$PODS" | tr -d ' \t\n\r')" ]; then
    # The cluster is not ready if no pods are found
    return 0
  fi

  NOT_READY=$(echo "$PODS" | awk '{
    if (NF == 0) next;
    if ($3 != "Running" && $3 != "Succeeded") {
      print 1;
      exit;
    }
    if ($3 == "Running" && $4 != "True") {
      print 1;
      exit;
    }
  }')
  if [ -n "$NOT_READY" ]; then
    # Some pods aren't running or ready
    return 0
  else
    # All pods are running and ready
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
SUCCESSES_NEEDED=3 # require three successes to make sure everything is settled

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

echo "pods..."
kubectl get pods -A || true

if [ "$EXITCODE" -ne 0 ]; then
  echo "Troubleshooting information for pods that are not ready..."
  PODS=$(kubectl get pods -A -o jsonpath="$JSONPATH")
  echo "$PODS" | tr -d "'" | awk '{
    if (NF == 0) next;
    if ($3 != "Running" && $3 != "Succeeded") {
      print $1, $2;
    } else if ($3 == "Running" && $4 != "True") {
      print $1, $2;
    }
  }' | while read -r POD_NAME NAMESPACE; do
    if [ -n "$POD_NAME" ] && [ -n "$NAMESPACE" ]; then
      echo "=================================================="
      echo "Describing pod $POD_NAME in namespace $NAMESPACE..."
      kubectl describe pod "$POD_NAME" -n "$NAMESPACE" || true
      echo "--------------------------------------------------"
      echo "Logs for pod $POD_NAME in namespace $NAMESPACE (current)..."
      kubectl logs "$POD_NAME" -n "$NAMESPACE" --all-containers --tail=100 || true
      echo "--------------------------------------------------"
      echo "Logs for pod $POD_NAME in namespace $NAMESPACE (previous)..."
      kubectl logs "$POD_NAME" -n "$NAMESPACE" --all-containers --tail=100 --previous || true
    fi
  done
fi

exit $EXITCODE
