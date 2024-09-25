#!/bin/bash
set -e
data=""
INPUTS="$(jq -r '.')"
KEYS="$(jq -r '.|keys|.[]' <<< "$INPUTS")"
for k in $KEYS; do
  # create an env variable for inputs, in this case it generates the "data" env variable from the "query"
  eval "$(echo "$INPUTS" | jq -r '@sh "'"$k"'=\(.'"$k"')"')"
done

DATA="$(jq -r '.' "$data")"
KEYS="$(jq -r '.|keys|.[]' <<< "$DATA")"
for k in $KEYS; do
  # create an env variable for each key in "$data"
  # WARNING! this can't handle complex types, only key(string) : value(string)
  eval "$(echo "$DATA" | jq -r '@sh "'"$k"'=\(.'"$k"'.value)"')"
done

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted and escaped to produce a valid JSON string.
# example CMD: jq -n --arg kubeconfig "$kubeconfig" '{"kubeconfig":$kubeconfig,"EOF":1}'

CMD='jq -n'
for v in $KEYS; do
  CMD="$CMD --arg $v \"$"
  CMD="$CMD$v\""
done
CMD="$CMD '{"
for v in $KEYS; do
  CMD="$CMD \"$v\":$"
  CMD="$CMD$v,"
done
CMD="$CMD\"EOF\":\"1\"}'"

eval "$CMD"
