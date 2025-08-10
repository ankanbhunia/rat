#!/bin/bash

generate_random_domain() {
  local TUNNEL_ORIGIN_CERT="$1"
  local keyword="$2" # Capture the first argument as keyword

  # Check file existence
  if [ ! -f "$TUNNEL_ORIGIN_CERT" ]; then
    echo "Error: File '$TUNNEL_ORIGIN_CERT' does not exist."
    return 1
  fi

  # Extract the base64 token content between the markers
  TOKEN_BASE64=$(sed -n '/-----BEGIN ARGO TUNNEL TOKEN-----/,/-----END ARGO TUNNEL TOKEN-----/p' "$TUNNEL_ORIGIN_CERT" | \
    sed '1d;$d' | tr -d '\n')

  if [ -z "$TOKEN_BASE64" ]; then
    echo "Error: No Argo Tunnel Token found in the file." >&2
    return 1
  fi

  # Decode the base64 token into JSON
  TOKEN_JSON=$(echo "$TOKEN_BASE64" | base64 --decode 2>/dev/null)

  if [ -z "$TOKEN_JSON" ]; then
    echo "Error: Failed to decode base64 token." >&2
    return 1
  fi

  # Extract zoneID and apiToken from JSON using jq
  ZONE_ID=$(echo "$TOKEN_JSON" | jq -r '.zoneID')
  API_TOKEN=$(echo "$TOKEN_JSON" | jq -r '.apiToken')

  if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ]; then
    echo "Error: zoneID not found in token." >&2
    return 1
  fi

  if [ -z "$API_TOKEN" ] || [ "$API_TOKEN" == "null" ]; then
    echo "Error: apiToken not found in token." >&2
    return 1
  fi

  # Call Cloudflare API to get domain name
  response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}" \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "Content-Type: application/json")

  domain_name=$(echo "$response" | jq -r '.result.name')

  if [ "$domain_name" == "null" ] || [ -z "$domain_name" ]; then
    echo "Failed to fetch domain info." >&2
    echo "Response from Cloudflare:" >&2
    echo "$response" >&2
    return 1
  fi

  HOSTNAME_SHORT=$(hostname -s)
  RANDOM_STRING=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8) # Changed to lowercase alphanumeric

  if [ -n "$keyword" ]; then # Check if keyword is provided
    echo "${HOSTNAME_SHORT}-${keyword}-${RANDOM_STRING}.${domain_name}"
  else
    echo "${HOSTNAME_SHORT}-${RANDOM_STRING}.${domain_name}"
  fi
}
