#!/usr/bin/env sh

ACTION="$1"
if [ -z "$ACTION" ]; then
  ACTION="apply"
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found, skipping reconcile"
  exit 0
fi

CLUSTER_NAME=""
if [ -f "inputs.tfvars" ]; then
  ENCODED_NAME=$(grep '^node_config_name' inputs.tfvars | cut -d'"' -f2 2>/dev/null || true)
  if [ -n "$ENCODED_NAME" ]; then
    CLUSTER_NAME=$(echo "$ENCODED_NAME" | base64 -d 2>/dev/null || true)
  fi
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "Cluster name could not be determined, skipping reconcile"
  exit 0
fi

NAMESPACE="fleet-default"

case "$ACTION" in
  apply)
    if kubectl get clusters.provisioning.cattle.io "$CLUSTER_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
      STATE_HAS_CLUSTER=0
      if [ -f "tfstate" ]; then
        if terraform state list -state="tfstate" 2>/dev/null | grep -q 'module.downstream.rancher2_cluster_v2.rke2_cluster'; then
          STATE_HAS_CLUSTER=1
        fi
      fi
      if [ "$STATE_HAS_CLUSTER" -eq 0 ]; then
        echo "Reconcile: Cluster $CLUSTER_NAME exists in Rancher but missing from state. Attempting import..."
        if ! terraform import -var-file="inputs.tfvars" -state="tfstate" module.downstream.rancher2_cluster_v2.rke2_cluster "$NAMESPACE/$CLUSTER_NAME"; then
          echo "Reconcile: Import failed, removing orphaned cluster $CLUSTER_NAME from Rancher..."
          kubectl delete clusters.provisioning.cattle.io "$CLUSTER_NAME" -n "$NAMESPACE" --timeout=120s || true
        fi
      fi
    fi
    ;;
  destroy)
    if kubectl get clusters.provisioning.cattle.io "$CLUSTER_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
      echo "Reconcile: Cluster $CLUSTER_NAME still exists in Rancher after destroy. Deleting via kubectl..."
      kubectl delete clusters.provisioning.cattle.io "$CLUSTER_NAME" -n "$NAMESPACE" --timeout=120s || true
    fi
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
