#!/usr/bin/env bash
#
# Helper: cleanup.sh
# Description: Cleans up AWS resources created during testing. Supports cleaning a specific ID,
#              listing leftover IDs (-l, -json), or cleaning all leftover resources (--all).

set -euo pipefail

DEFAULT_OWNER="terraform-ci@suse.com"
DEFAULT_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}"

OWNER="${DEFAULT_OWNER}"
AWS_REGION="${DEFAULT_REGION}"
LIST_ONLY=false
OUTPUT_JSON=false
CLEANUP_ALL=false
CLEANUP_ID=""

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [CLEANUP_ID]

Cleans up AWS resources created during testing. Can target a specific ID, list leftover IDs,
or clean up all leftover resources discovered in AWS.

Arguments:
  CLEANUP_ID                 Specific resource cleanup ID to delete

Options:
  -l                         List all leftover resource IDs found (does not delete)
  -json, --json              When listing (-l), output full object information as JSON
  --all                      Find and clean up all leftover resources (based on Owner tag)
  -r, --region <region>      AWS region to query (default: ${DEFAULT_REGION})
  -o, --owner <email>        Owner tag value to filter by (default: ${DEFAULT_OWNER})
  -h, --help                 Show this help message and exit

Examples:
  $(basename "$0") 44193634266-TestProductionBasic-5bi31M
  $(basename "$0") -l
  $(basename "$0") -l -json
  $(basename "$0") --all
  $(basename "$0") --all --region us-east-1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l)
      LIST_ONLY=true
      shift
      ;;
    -json|--json)
      OUTPUT_JSON=true
      shift
      ;;
    --all)
      CLEANUP_ALL=true
      shift
      ;;
    -r|--region)
      AWS_REGION="$2"
      shift 2
      ;;
    -o|--owner)
      OWNER="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      echo "Error: Unknown option '$1'" >&2
      show_help >&2
      exit 1
      ;;
    *)
      if [[ -z "${CLEANUP_ID}" ]]; then
        CLEANUP_ID="$1"
        shift
      else
        echo "Error: Unexpected argument '$1'" >&2
        show_help >&2
        exit 1
      fi
      ;;
  esac
done

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: 'aws' CLI is required but not installed." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required but not installed." >&2
  exit 1
fi

check_resource_exists() {
  local arn="$1"
  local service
  local res_type
  local res_id
  local reg

  service=$(echo "$arn" | cut -d: -f3)
  reg=$(echo "$arn" | cut -d: -f4)
  reg="${reg:-$AWS_REGION}"

  if [[ "$service" == "ec2" ]]; then
    res_type=$(echo "$arn" | cut -d: -f6 | cut -d/ -f1)
    res_id=$(echo "$arn" | awk -F'/' '{print $NF}')
    case "$res_type" in
      volume)
        aws ec2 describe-volumes --volume-ids "$res_id" --region "$reg" >/dev/null 2>&1
        return $?
        ;;
      internet-gateway)
        aws ec2 describe-internet-gateways --internet-gateway-ids "$res_id" --region "$reg" >/dev/null 2>&1
        return $?
        ;;
      instance)
        local state
        state=$(aws ec2 describe-instances --instance-ids "$res_id" --region "$reg" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || true)
        if [[ -z "$state" || "$state" == "terminated" || "$state" == "None" ]]; then
          return 1
        fi
        return 0
        ;;
      key-pair)
        aws ec2 describe-key-pairs --key-pair-ids "$res_id" --region "$reg" >/dev/null 2>&1
        return $?
        ;;
      *)
        return 0
        ;;
    esac
  elif [[ "$service" == "secretsmanager" ]]; then
    aws secretsmanager describe-secret --secret-id "$arn" --region "$reg" >/dev/null 2>&1
    return $?
  elif [[ "$service" == "s3" ]]; then
    local bucket
    bucket=$(echo "$arn" | awk -F'arn:aws:s3:::' '{print $2}')
    aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1
    return $?
  fi
  return 0
}

discover_leftover_resources() {
  local output_file="$1"
  local tmp_items_file
  tmp_items_file=$(mktemp)
  echo "[]" > "${tmp_items_file}"

  local pagination_token=""

  while :; do
    local args=(
      resourcegroupstaggingapi get-resources
      --region "${AWS_REGION}"
      --tag-filters "Key=Owner,Values=${OWNER}"
      --no-cli-pager
      --output json
    )

    if [[ -n "${pagination_token}" ]]; then
      args+=(--pagination-token "${pagination_token}")
    fi

    local response
    response=$(aws "${args[@]}" 2>/dev/null || true)
    if [[ -z "${response}" ]]; then
      break
    fi

    local page_items
    page_items=$(echo "${response}" | jq '.ResourceTagMappingList // []' 2>/dev/null || true)
    if [[ -n "${page_items}" && "${page_items}" != "[]" ]]; then
      local merged
      merged=$(jq -s '.[0] + .[1]' "${tmp_items_file}" <(echo "${page_items}"))
      echo "${merged}" > "${tmp_items_file}"
    fi

    pagination_token=$(echo "${response}" | jq -r '.PaginationToken // empty' 2>/dev/null || true)
    if [[ -z "${pagination_token}" ]]; then
      break
    fi
  done

  # Query IAM server certificates
  local cert_names
  cert_names=$(aws iam list-server-certificates --no-cli-pager --output json 2>/dev/null \
    | jq -r '.ServerCertificateMetadataList[]?.ServerCertificateName' 2>/dev/null || true)

  if [[ -n "${cert_names}" ]]; then
    local iam_certs="[]"
    while IFS= read -r cert_name; do
      if [[ -z "${cert_name}" ]]; then
        continue
      fi
      local cert_tags_resp
      cert_tags_resp=$(aws iam list-server-certificate-tags --server-certificate-name "${cert_name}" --no-cli-pager --output json 2>/dev/null || true)
      if [[ -n "${cert_tags_resp}" ]]; then
        local is_owned
        is_owned=$(echo "${cert_tags_resp}" | jq -r --arg OWNER "${OWNER}" '
          any(.Tags[]?; .Key == "Owner" and .Value == $OWNER)
        ' 2>/dev/null || true)
        if [[ "${is_owned}" == "true" ]]; then
          local cert_obj
          cert_obj=$(echo "${cert_tags_resp}" | jq --arg NAME "${cert_name}" '
            {
              ResourceARN: ("arn:aws:iam::server-certificate/" + $NAME),
              Tags: (.Tags // [])
            }
          ' 2>/dev/null || true)
          if [[ -n "${cert_obj}" ]]; then
            iam_certs=$(jq -s '.[0] + [.[1]]' <(echo "${iam_certs}") <(echo "${cert_obj}"))
          fi
        fi
      fi
    done <<< "${cert_names}"

    if [[ "${iam_certs}" != "[]" ]]; then
      local merged
      merged=$(jq -s '.[0] + .[1]' "${tmp_items_file}" <(echo "${iam_certs}"))
      echo "${merged}" > "${tmp_items_file}"
    fi
  fi

  # Filter to existing resources
  echo "[]" > "${output_file}"
  local item_count
  item_count=$(jq 'length' "${tmp_items_file}")
  for (( i=0; i<item_count; i++ )); do
    local item
    item=$(jq -c ".[$i]" "${tmp_items_file}")
    local arn
    arn=$(echo "${item}" | jq -r '.ResourceARN')

    if check_resource_exists "${arn}"; then
      local item_with_exists
      item_with_exists=$(echo "${item}" | jq '. + {Exists: true}')
      local merged
      merged=$(jq -s '.[0] + [.[1]]' "${output_file}" <(echo "${item_with_exists}"))
      echo "${merged}" > "${output_file}"
    fi
  done

  rm -f "${tmp_items_file}"
}

cleanup_single_id() {
  local target_id="$1"
  local IDENTIFIER="$target_id"
  local max_attempts=3

  echo "Starting cleanup for Id: $IDENTIFIER in $AWS_REGION"

  local resources_to_clear=""
  if command -v leftovers >/dev/null 2>&1; then
    resources_to_clear="$(leftovers -d --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$IDENTIFIER" 2>/dev/null | grep -v 'AccessDenied' || true)"
    local resources_ids=""
    resources_ids="$(echo "$resources_to_clear" | awk -F"Id:" '{print $2}' | awk -F"," '{print $1}' | awk -F")" '{print $1}' | sort | uniq)"

    echo "   resources found:"
    while IFS= read -r r; do
      if [ -n "$r" ]; then echo "    $r"; fi
    done <<<"$resources_to_clear"

    echo "   resources ids:"
    for r in $resources_ids; do
      if [ -n "$r" ]; then echo "    $r"; fi
    done

    if [ -z "$resources_ids" ]; then resources_ids=$IDENTIFIER; fi

    for sub_id in $resources_ids; do
      local sub_identifier="$sub_id"
      local attempts=0

      resources_to_clear="$(leftovers -d --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$sub_identifier" 2>/dev/null | grep -v 'AccessDenied' || true)"
      while [ -n "$resources_to_clear" ] && [ $attempts -lt $max_attempts ]; do
        echo -e "found these resources to clear:\n $resources_to_clear\n"
        leftovers --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$sub_identifier" --no-confirm 2>/dev/null | grep -v 'AccessDenied' || true
        sleep 10
        resources_to_clear="$(leftovers -d --iaas=aws --aws-region="$AWS_REGION" --filter="Id:$sub_identifier" 2>/dev/null | grep -v 'AccessDenied' || true)"
        if [ -n "$resources_to_clear" ]; then
          echo "Some resources failed to clear, retrying in $((attempts * 10)) seconds..."
        fi
        sleep $((attempts * 10))
        attempts=$((attempts + 1))
      done

      if [ $attempts -eq $max_attempts ]; then
        echo "Warning: Failed to clear all resources after $max_attempts attempts."
      fi
    done
  fi

  # remove secrets
  echo "Clearing out secrets if they were missed..."
  local attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r arn; do
      if [ -z "$arn" ]; then
        continue
      fi
      echo "removing secret $arn..."
      aws secretsmanager delete-secret --secret-id "$arn" --force-delete-without-recovery >/dev/null 2>&1 || true
    done <<<"$(aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "secretsmanager:secret" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN')"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done

  # remove s3 storage
  echo "Clearing out s3 buckets if they were missed..."
  attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r b_id; do
      if [ -z "$b_id" ]; then
        continue
      fi
      echo "   removing s3 bucket $b_id..."
      echo "   clearing out versions..."
      while read -r v; do
        if [ -z "$v" ]; then continue; fi;
        aws s3api delete-object --bucket "$b_id" --key "tfstate" --version-id="$v" > /dev/null 2>&1 || true
      done <<<"$(aws s3api list-object-versions --bucket "$b_id" 2>/dev/null | jq -r '.DeleteMarkers[]?.VersionId' || true)"
      while read -r v; do
        if [ -z "$v" ]; then continue; fi;
        aws s3api delete-object --bucket "$b_id" --key "tfstate" --version-id="$v" > /dev/null 2>&1 || true
      done <<<"$(aws s3api list-object-versions --bucket "$b_id" 2>/dev/null | jq -r '.Versions[]?.VersionId' || true)"
      echo "   removing bucket..."
      aws s3 rb "s3://$b_id" --force >/dev/null 2>&1 || true
    done <<<"$(aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "s3:bucket" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN' | awk -F'arn:aws:s3:::' '{print $2}' || true)"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done

  # remove key pairs
  echo "Clearing out key pairs if they were missed..."
  attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r kp_id; do
      if [ -z "$kp_id" ]; then
        continue
      fi
      echo "   removing ec2 key pair $kp_id..."
      aws ec2 delete-key-pair --key-pair-id "$kp_id" --region "$AWS_REGION" >/dev/null 2>&1 || true
    done <<<"$(aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "ec2:key-pair" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN' | awk -F'/' '{print $2}')"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done

  # remove ebs volumes
  echo "Clearing out ebs volumes if they were missed..."
  attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r arn; do
      if [ -z "$arn" ]; then
        continue
      fi
      local vol_id
      vol_id=$(echo "$arn" | awk -F'/' '{print $NF}')
      local vol_region
      vol_region=$(echo "$arn" | cut -d: -f4)
      vol_region="${vol_region:-$AWS_REGION}"
      echo "   checking ec2 volume $vol_id in $vol_region..."
      local vol_state
      vol_state=$(aws ec2 describe-volumes --volume-ids "$vol_id" --region "$vol_region" --query 'Volumes[0].State' --output text 2>/dev/null || true)
      if [ -z "$vol_state" ] || [ "$vol_state" = "None" ]; then
        echo "   ec2 volume $vol_id is already deleted (cached by Tagging API)."
        continue
      fi
      if [ "$vol_state" = "in-use" ]; then
        echo "   detaching in-use volume $vol_id..."
        aws ec2 detach-volume --volume-id "$vol_id" --region "$vol_region" --force > /dev/null 2>&1 || true
        aws ec2 wait volume-available --volume-ids "$vol_id" --region "$vol_region" 2>/dev/null || sleep 5
      fi
      echo "   deleting ec2 volume $vol_id..."
      aws ec2 delete-volume --volume-id "$vol_id" --region "$vol_region" > /dev/null 2>&1 || true
    done <<<"$( {
      aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "ec2:volume" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN';
      aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "ec2:volume" --tag-filters "Key=ID,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN';
    } | sort -u )"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done

  # remove internet gateways
  echo "Clearing out internet gateways if they were missed..."
  attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r arn; do
      if [ -z "$arn" ]; then
        continue
      fi
      local igw_id
      igw_id=$(echo "$arn" | awk -F'/' '{print $NF}')
      local igw_region
      igw_region=$(echo "$arn" | cut -d: -f4)
      igw_region="${igw_region:-$AWS_REGION}"
      echo "   checking internet gateway $igw_id in $igw_region..."

      # Check if attached to any VPC. If attached, do not delete the IGW; report an error and skip.
      local attachments
      attachments=$(aws ec2 describe-internet-gateways --internet-gateway-ids "$igw_id" --region "$igw_region" --query 'InternetGateways[0].Attachments[*].VpcId' --output text 2>/dev/null || true)
      local has_vpc=0
      for vpc_id in $attachments; do
        if [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
          echo "   ERROR: internet gateway $igw_id is attached to VPC $vpc_id. Delete the VPC instead of detaching the IGW." >&2
          has_vpc=1
        fi
      done
      if [ $has_vpc -eq 1 ]; then
        continue
      fi

      echo "   deleting orphaned internet gateway $igw_id..."
      aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" --region "$igw_region" > /dev/null 2>&1 || true
    done <<<"$( {
      aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "ec2:internet-gateway" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN';
      aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "ec2:internet-gateway" --tag-filters "Key=ID,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN';
    } | sort -u )"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done

  # remove server certificates
  echo "Clearing out server certificates if they were missed..."
  attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r name; do
      if [ -z "$name" ]; then
        continue
      fi
      if aws iam list-server-certificate-tags --server-certificate-name "$name" 2>/dev/null | jq -e --arg ID "$IDENTIFIER" '.Tags[] | select((.Key=="Id" or .Key=="ID") and (.Value | contains($ID)))' > /dev/null 2>&1; then
        echo "   removing iam server certificate $name..."
        aws iam delete-server-certificate --server-certificate-name "$name" >/dev/null 2>&1 || true
      fi
    done <<<"$(aws iam list-server-certificates --no-cli-pager 2>/dev/null | jq -r '.ServerCertificateMetadataList[]?.ServerCertificateName' || true)"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done

  # remove load balancer target groups
  echo "Clearing out load balancer target groups if they were missed..."
  attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r arn; do
      if [ -z "$arn" ]; then
        continue
      fi
      echo "   removing load balancer target group $arn..."
      aws elbv2 delete-target-group --target-group-arn "$arn" --region "$AWS_REGION" >/dev/null 2>&1 || true;
    done <<<"$( {
      aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "elasticloadbalancing:targetgroup" --tag-filters "Key=Id,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN';
      aws resourcegroupstaggingapi get-resources --no-cli-pager --region "$AWS_REGION" --resource-type-filters "elasticloadbalancing:targetgroup" --tag-filters "Key=ID,Values=$IDENTIFIER" | jq -r '.ResourceTagMappingList[]?.ResourceARN';
    } | sort -u )"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done

  # remove route 53 records
  echo "Clearing out Route 53 records if they were missed..."
  local LOWER_IDENTIFIER
  LOWER_IDENTIFIER=$(echo "$IDENTIFIER" | tr '[:upper:]' '[:lower:]')
  attempts=0
  while [ $attempts -lt $max_attempts ]; do
    while read -r hz; do
      if [ -z "$hz" ]; then
        continue
      fi
      hz="${hz#/hostedzone/}"
      while read -r record; do
        if [ -z "$record" ]; then
          continue
        fi
        local record_name
        record_name=$(echo "$record" | jq -r '.Name')
        local record_type
        record_type=$(echo "$record" | jq -r '.Type')
        echo "   removing route 53 record $record_name of type $record_type from zone $hz..."
        local change_batch
        change_batch=$(jq -n --argjson rec "$record" '{"Changes": [{"Action": "DELETE", "ResourceRecordSet": $rec}]}')
        aws route53 change-resource-record-sets --hosted-zone-id "$hz" --change-batch "$change_batch" > /dev/null 2>&1 || true
      done <<<"$(aws route53 list-resource-record-sets --hosted-zone-id "$hz" 2>/dev/null | jq -c --arg ID "$LOWER_IDENTIFIER" '.ResourceRecordSets[]? | select(.Name | contains($ID))' || true)"
    done <<<"$(aws route53 list-hosted-zones --no-cli-pager 2>/dev/null | jq -r '.HostedZones[]?.Id' || true)"
    sleep $((attempts * 10))
    attempts=$((attempts + 1))
  done
}

# --- Execution Entrypoint ---

if [[ "${LIST_ONLY}" == "true" ]]; then
  tmp_res_file=$(mktemp)
  trap 'rm -f "${tmp_res_file}"' EXIT

  discover_leftover_resources "${tmp_res_file}"

  if [[ "${OUTPUT_JSON}" == "true" ]]; then
    jq '
      map(
        . as $item
        | ($item.Tags // []) as $tags
        | ($tags | map({ (.Key): .Value }) | add // {}) as $tagMap
        | ($tags[]? | select((.Key | ascii_downcase) == "id") | .Value) as $id
        | ($item.ResourceARN | split(":")) as $arnParts
        | {
            ResourceARN: $item.ResourceARN,
            Id: ($id // null),
            ResourceType: ($arnParts[5] // null | split("/")[0]),
            Region: (if ($arnParts[3] // "") == "" then null else $arnParts[3] end),
            Owner: ($tagMap["Owner"] // null),
            Exists: true,
            TagMap: $tagMap,
            Tags: $tags
          }
      )
    ' "${tmp_res_file}"
  else
    jq -r '
      .[].Tags[]?
      | select((.Key | ascii_downcase) == "id")
      | .Value
    ' "${tmp_res_file}" | grep -v '^$' | sort -u || true
  fi
  exit 0
fi

if [[ "${CLEANUP_ALL}" == "true" ]]; then
  echo "Discovering leftover resources owned by ${OWNER} in ${AWS_REGION}..."
  tmp_res_file=$(mktemp)
  trap 'rm -f "${tmp_res_file}"' EXIT

  discover_leftover_resources "${tmp_res_file}"

  found_ids=()
  while IFS= read -r id; do
    if [[ -n "${id}" ]]; then
      found_ids+=("${id}")
    fi
  done < <(jq -r '.[].Tags[]? | select((.Key | ascii_downcase) == "id") | .Value' "${tmp_res_file}" | grep -v '^$' | sort -u || true)

  if [[ ${#found_ids[@]} -eq 0 ]]; then
    echo "No leftover resources found."
    exit 0
  fi

  echo "Found ${#found_ids[@]} leftover ID(s):"
  for id in "${found_ids[@]}"; do
    echo "   $id"
  done

  # Phase 1: Clean up by prefix so leftovers tool matches all resources with same prefix
  echo ""
  echo "=== Phase 1: Cleaning up by unique ID prefix ==="
  prefixes=()
  while IFS= read -r pfx; do
    if [[ -n "${pfx}" ]]; then
      prefixes+=("${pfx}")
    fi
  done < <(printf "%s\n" "${found_ids[@]}" | awk -F- '{print $1}' | grep -v '^$' | sort -u)

  for pfx in "${prefixes[@]}"; do
    echo "--- Cleaning prefix: $pfx ---"
    cleanup_single_id "$pfx"
  done

  # Phase 2: Clean up by full ID for manual fallback routines
  echo ""
  echo "=== Phase 2: Cleaning up by full ID ==="
  for id in "${found_ids[@]}"; do
    echo "--- Cleaning full ID: $id ---"
    cleanup_single_id "$id"
  done

  echo ""
  echo "All cleanup phases completed."
  exit 0
fi

if [[ -z "${CLEANUP_ID}" ]]; then
  echo "Error: No cleanup ID provided, and neither -l nor --all was specified." >&2
  show_help >&2
  exit 1
fi

cleanup_single_id "${CLEANUP_ID}"
echo "Cleanup completed."
