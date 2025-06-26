#!/bin/bash
set -e
INPUTS="$(jq -r '.')"
FILENAMEFILE="$(jq -r '.filename_file' <<<"$INPUTS")"
NEWFILE="$(jq -r '.filename' <<<"$INPUTS")"

if [ -z "$FILENAMEFILE" ]; then
  echo "filename_file required" >&2
  exit 1
fi

if [ -z "$NEWFILE" ]; then
  echo "filename required" >&2
  exit 1
fi

install -d "$(dirname "$FILENAMEFILE")"
touch "$FILENAMEFILE"

# grep returns 1 if the pattern isn't found, so we need to ignore the "failure" here
NEW="$(grep -l "$NEWFILE" "$FILENAMEFILE" || true)"

if [ -z "$NEW" ]; then
  echo "$NEWFILE" >> "$FILENAMEFILE"
fi

while read -r FILEPATH; do
  if [ -z "$FILEPATH" ]; then continue; fi # ignore empty lines
  DIRECTORY="$(dirname "$FILEPATH")"
  install -d "$DIRECTORY"
  touch "$FILEPATH"
done < "$FILENAMEFILE"

jq -n '{"outcome": "success"}'
