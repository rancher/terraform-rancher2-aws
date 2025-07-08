#!/bin/bash
set -e

JSON_INPUT="$(jq -r '.')"
FILEPATH="$(jq -r '.filepath' <<<"$JSON_INPUT")"

DATA=""
if [ -n "$FILEPATH" ]; then
  if [ -f "$FILEPATH" ]; then
    DATA="$(cat "$FILEPATH")"
  fi
fi

jq -n --arg data "$DATA" '{"data": $data}'
