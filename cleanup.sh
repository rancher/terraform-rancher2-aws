#!/bin/bash

# This script is run by the run_tests.sh script to clean up AWS resources created during testing.
# It can also be run independently to clean up resources by providing a cleanup ID.
cleanup_id="$1"
if [ -z "$cleanup_id" ]; then
  echo "No cleanup Id provided. Exiting."
  exit 1
fi
echo "Starting cleanup for Id: $cleanup_id"
IDENTIFIER="$cleanup_id"
AWS_REGION="${AWS_REGION:-us-west-2}"

echo "Clearing leftovers with Id $IDENTIFIER in $AWS_REGION..."

max_attempts=3

attempts=0
resources_to_clear="$(leftovers -d --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$IDENTIFIER" | grep -v 'AccessDenied')"
while [ -n "$resources_to_clear" ] && [ $attempts -lt $max_attempts ]; do
  echo -e "found these resources to clear:\n $resources_to_clear\n"
  leftovers --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$IDENTIFIER" --no-confirm | grep -v 'AccessDenied' || true
  sleep 10
  resources_to_clear="$(leftovers -d --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$IDENTIFIER" | grep -v 'AccessDenied')"
  if [ -n "$resources_to_clear" ]; then
    echo "Some resources failed to clear, retrying in $((attempts * 10)) seconds..."
  fi
  sleep $((attempts * 10))
  attempts=$((attempts + 1))
done

if [ $attempts -eq $max_attempts ]; then
  echo "Warning: Failed to clear all resources after $max_attempts attempts."
fi

# remove secrets
attempts=0
while [ $attempts -lt $max_attempts ]; do
  while read -r arn; do
    if [ -z "$arn" ]; then
      continue
    fi
    echo "removing secret $arn..."
    aws secretsmanager delete-secret --secret-id "$arn" --force-delete-without-recovery
  done <<<"$(aws resourcegroupstaggingapi get-resources --no-cli-pager --resource-type-filters "secretsmanager:secret" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN')"
  sleep $((attempts * 10))
  attempts=$((attempts + 1))
done

# remove s3 storage
attempts=0
while [ $attempts -lt $max_attempts ]; do
  while read -r id; do
    if [ -z "$id" ]; then
      continue
    fi
    echo "removing s3 bucket $id..."
    aws s3 rb "s3://$id" --force
  done <<<"$(aws resourcegroupstaggingapi get-resources --no-cli-pager --resource-type-filters "s3:bucket" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN' | awk -F'arn:aws:s3:::' '{print $2}')"
  sleep $((attempts * 10))
  attempts=$((attempts + 1))
done

# remove key pairs
attempts=0
while [ $attempts -lt $max_attempts ]; do
  while read -r id; do
    if [ -z "$id" ]; then
      continue
    fi
    echo "removing ec2 key pair $id..."
    aws ec2 delete-key-pair --key-pair-id "$id"
  done <<<"$(aws resourcegroupstaggingapi get-resources --no-cli-pager --resource-type-filters "ec2:key-pair" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN' | awk -F'/' '{print $2}')"
  sleep $((attempts * 10))
  attempts=$((attempts + 1))
done

# remove server certificates
# unfortunately get-resources doesn't support iam server certificates
attempts=0
while [ $attempts -lt $max_attempts ]; do
  while read -r name; do
    if [ -z "$name" ]; then
      continue
    fi
    if aws iam list-server-certificate-tags --server-certificate-name "$name" | jq -e --arg ID "$IDENTIFIER" '.Tags[] | select(.Key=="Id" and .Value==$ID)' > /dev/null; then
      echo "removing iam server certificate $name..."
      aws iam delete-server-certificate --server-certificate-name "$name"
    fi
  done <<<"$(aws iam list-server-certificates | jq -r '.ServerCertificateMetadataList[].ServerCertificateName')"
  sleep $((attempts * 10))
  attempts=$((attempts + 1))
done

# remove load balancer target groups
attempts=0
while [ $attempts -lt $max_attempts ]; do
  while read -r arn; do
    if [ -z "$arn" ]; then
      continue
    fi
    echo "removing load balancer target group $arn..."
    aws elbv2 delete-target-group --target-group-arn "$arn";
  done <<<"$(aws resourcegroupstaggingapi get-resources --no-cli-pager --resource-type-filters "elasticloadbalancing:targetgroup" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN')"
  sleep $((attempts * 10))
  attempts=$((attempts + 1))
done

echo "Cleanup completed."

# These examples find Ids that need to be cleaned up by looking for resources owned by CI and extracting their Id tags.
# This is useful if you happen to come across leftover resources and want to clean up anything that might have been missed with their specific Id.
# For example, if you hit a quota limit and notice there a bunch of leftover secrets or target groups, you can run these commands to clean up all resources with the same Id as the leftover resources.
# for id in $(aws resourcegroupstaggingapi get-resources --no-cli-pager --resource-type-filters "elasticloadbalancing:targetgroup" --tag-filters "Key=Owner,Values=terraform-ci@suse.com" | jq -r '.ResourceTagMappingList[]?.Tags[] | select(.Key=="Id") | .Value'); do ./cleanup.sh "$id"; done
# for id in $(aws resourcegroupstaggingapi get-resources --no-cli-pager --resource-type-filters "secretsmanager:secret" --tag-filters "Key=Owner,Values=terraform-ci@suse.com" | jq -r '.ResourceTagMappingList[]?.Tags[] | select(.Key=="Id") | .Value'); do ./cleanup.sh "$id"; done
# for id in $(for name in $(aws iam list-server-certificates | jq -r '.ServerCertificateMetadataList[].ServerCertificateName'); do echo "$(aws iam list-server-certificate-tags --server-certificate-name "$name" | jq -r '.Tags[] | select(.Key=="Id").Value')"; done); do echo "$id"; done
