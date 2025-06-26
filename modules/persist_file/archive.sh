# !/bin/bash
set -e


# This script can compress text into smaller text or decompress that text back to its original form
# this requires: xz, openssl, jq, bash, and core linux utils (echo, redirection, pipe)
JSON_INPUT="$(jq -r '.')"
COMPRESS="$(jq -r '.compress' <<<"$JSON_INPUT")"
DECOMPRESS="$(jq -r '.decompress' <<<"$JSON_INPUT")"
DATA="$(jq -r '.contents' <<<"$JSON_INPUT")"

if [ -n "$COMPRESS" ] && [ "null" != "$COMPRESS" ]; then
  ENCODED_OUTPUT="$(printf "%s" "$DATA" | xz -c -9 -e -T0 | openssl base64 -A -)"
fi

if [ -n "$DECOMPRESS" ] && [ "null" != "$DECOMPRESS" ]; then
  ENCODED_OUTPUT="$(echo -n "$DATA" | openssl base64 -d -A | xz -dc | openssl base64 -A -)"
fi

if [ -z "$ENCODED_OUTPUT" ]; then
  echo "output is empty" >&2
  exit 1
fi

jq -n --arg data "$ENCODED_OUTPUT" '{"data": $data}'
