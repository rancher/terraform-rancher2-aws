#!/bin/bash
set -x

JSONPATH="'{range .items[*]}
  {.metadata.name}{\"\\t\"} \
  {.metadata.namespace}{\"\\t\"} \
  {.status.readyReplicas}{\"\\t\"} \
  {.status.replicas}{\"\\n\"} \
{end}'"

notReady() {
  NOT_READY=""
  ITEMS="$(kubectl get deployments -A -o jsonpath="$JSONPATH")"
  while IFS= read -r item; do
    ready="$(echo "$item" | awk '{print $3}')"
    total="$(echo "$item" | awk '{print $4}')"
    if [ "$ready" != "$total" ]; then
      NOT_READY=1
    fi
  done <<< "$ITEMS"
  # shellcheck disable=SC2060,SC2140
  if [ -z "$NOT_READY" ]; then
    # All items are ready
    return 1
  else
    # Some items aren't ready
    return 0
  fi
}

readyWait() {
  TIMEOUT=10 # 10 minutes
  TIMEOUT_MINUTES=$((TIMEOUT * 60))
  INTERVAL=30 # 30 seconds
  MAX=$((TIMEOUT_MINUTES / INTERVAL))
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

exit $EXITCODE
