#!/bin/bash
set -e

# Parse the JSON inputs from Terraform via stdin securely
eval "$(jq -r '@sh "API_URL=\(.api_url) ADMIN_PASSWORD=\(.admin_password) ADMIN_TOKEN=\(.admin_token)"')"

# Test token validity against an authenticated API endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -H "Authorization: Bearer $ADMIN_TOKEN" "$API_URL/v3/users?me=true")

if [ "$HTTP_CODE" -eq 200 ]; then
  # Token is valid, return the original token back to Terraform
  jq -n --arg token "$ADMIN_TOKEN" '{"admin_token": $token}'
else
  # Token is invalid or expired. Login with the admin password to get a new one.
  JSON_PAYLOAD=$(jq -n --arg username "admin" --arg password "$ADMIN_PASSWORD" --arg responseType "json" '{"username": $username, "password": $password, "responseType": $responseType}')
  
  LOGIN_RESPONSE=$(curl -s -k -X POST -H 'Content-Type: application/json' -d "$JSON_PAYLOAD" "$API_URL/v3-public/localProviders/local?action=login")
  
  NEW_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')
  
  if [ -z "$NEW_TOKEN" ]; then
    echo "Failed to retrieve new token from login endpoint. Response: $LOGIN_RESPONSE" >&2
    exit 1
  fi

  # Return the newly generated token back to Terraform
  jq -n --arg token "$NEW_TOKEN" '{"admin_token": $token}'
fi
