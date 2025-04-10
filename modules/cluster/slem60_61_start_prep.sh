#!/bin/bash

echo "checking selinux policy for new nginx version in sle-micro-60..."

SERVICE="apply-nginx-ingress-selinux-policy"
SERVICE_DIRECTORY="/etc/systemc/system/"
SERVICE_FILE="${SERVICE_DIRECTORY}/${SERVICE}.service"
POLICY_NAME="slemicro_60_nginx_ingress_policy"

ls -lah $SERVICE_FILE
ls -Z $SERVICE_FILE
cat $SERVICE_FILE

ls -lah /usr/bin/$SERVICE.sh
ls -Z /usr/bin/$SERVICE.sh
cat /usr/bin/$SERVICE.sh

ls -lah /etc/rancher/rke2
ls -lah /etc/rancher/rke2/policy

journalctl -u $SERVICE > log.txt
echo "the current time is $(date)..."
cat log.txt

POLICY_FOUND="$(semodule -l | grep $POLICY_NAME)"
if [ -z "$POLICY_FOUND" ]; then
  echo "policy isn't enabled..."
  export E=1
else
  echo "$POLICY_FOUND"
  echo "policy is enabled..."
  export E=0
fi

# i=0
# MAX=6
# while [ $i -lt $MAX ]; do
#   ausearch -m AVC,USER_AVC,SELINUX_ERR,USER_SELINUX_ERR
#   sleep 10
#   i=$((i+1))
# done

exit $E
