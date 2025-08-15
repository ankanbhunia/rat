#!/bin/bash

generate_random_domain() {
  local domainfile="$1"
  local keyword="$2" # Capture the first argument as keyword

  # Read domain name from .domain file
  if [ ! -f "$domainfile" ]; then
    echo "Error: .domain file not found in the root directory." >&2
    return 1
  fi
  domain_name=$(cat $domainfile)

  if [ -z "$domain_name" ]; then
    echo "Error: Domain name not found in .domain file." >&2
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
