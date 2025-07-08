#!/bin/bash
set -e

JSON_INPUT="$(jq -r '.')"
FILEPATH="$(jq -r '.filepath' <<<"$JSON_INPUT")"

jq -n --rawfile data "$FILEPATH" '{"data": $data}' 2>/dev/null || jq -n '{"data":"error"}'
