#!/bin/bash

port=""
domain=""
subpage_path=""
protocol="http"
help_flag=false
history_flag=false

# Function to display script usage
usage() {
    echo "Usage: rat-cli tunnel --port <PORT> [OPTIONS]"
    echo "Description: Creates a Cloudflare tunnel to expose a local port to the internet."
    echo "             This can be used to share local services or make a machine SSH-accessible."
    echo ""
    echo "Options:"
    echo "  --port <PORT>         The local port to expose. (Required for new tunnels)"
    echo "  --domain <DOMAIN>     (Optional) A custom domain to use for the tunnel (e.g., myapp.runs.space)."
    echo "                        Requires prior Cloudflare domain setup and 'rat-cli login'."
    echo "  --subpage_path <PATH> (Optional) A path to append to the tunnel URL (e.g., for sharing a specific file)."
    echo "  --protocol <PROTOCOL> (Optional) The protocol for the tunnel service (e.g., http, ssh). Default: http"
    echo "  --history             (Optional) List all active Cloudflare tunnels, sorted by newest created."
    echo "  -h, --help            Display this help message and exit."
    echo ""
    echo "Requirements:"
    echo "  - 'rat-cli login' must have been run successfully to obtain a Cloudflare certificate."
    echo "  - 'cloudflared-linux-amd64' executable must be present in the 'rat' directory."
    echo "  - The specified local port must be accessible."
    echo ""
    echo "Examples:"
    echo "  rat-cli tunnel --port 8000"
    echo "  rat-cli tunnel --port 3000 --domain myapp.runs.space"
    echo "  rat-cli tunnel --port 22 --domain mymachine.runs.space --protocol ssh"
    echo "  rat-cli tunnel --port 8080 --subpage_path my_report.pdf"
    exit 0
}
highlight_url() {
    local url="$1"
    local url_length=${#url}
    local box_width=$((url_length + 4)) # 2 spaces on each side

    echo -e "\e[1m\e[32m" # Bold and green text
    echo "┌$(printf '─%.0s' $(seq 1 $box_width))┐"
    echo "│  ${url}  │"
    echo "└$(printf '─%.0s' $(seq 1 $box_width))┘"
    echo -e "\e[0m" # Reset formatting
}
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            shift
            port="$1"
            ;;
        --domain)
            shift
            domain="$1"
            ;;
        --protocol)
            shift
            protocol="$1"
            ;;
        --subpage_path)
            shift
            subpage_path="$1"
            ;;
        -h|--help)
            help_flag=true
            ;;
        --history)
            history_flag=true
            ;;
        *)
            echo -e "\e[31mError: Unknown option '$1'\e[0m"
            usage
            ;;
    esac
    shift
done

if "$help_flag"; then
    usage
fi

if "$history_flag"; then
    echo "Listing active Cloudflare tunnels:"
    # Use cloudflared tunnel list and parse its output
    # The output format is typically a table. We need to skip the header,
    # then sort by the "CREATED AT" column.
    # Example output:
    # ID                                   NAME      CREATED AT                 CONNECTIONS
    # 12345678-abcd-abcd-abcd-1234567890ab my-tunnel 2023-10-27T10:00:00Z       1
    #
    # We need to extract the full line and the timestamp for sorting.
    # The timestamp is in ISO 8601 format, which can be directly sorted lexicographically.

    # Get the raw output
    tunnel_list_output=$(./cloudflared-linux-amd64 tunnel list --rd --invert-sort)

    # Check if the output contains "No tunnels found"
    if echo "$tunnel_list_output" | grep -q "No tunnels found"; then
        echo "No active tunnels found."
    else
        counter=1
        echo "$tunnel_list_output" | grep -E '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}' | awk '{print $1, $2, $3 " " $4, $5}' | sort -k3,3 | while read -r id name created_at connections; do
            # Extract date part from CREATED AT (e.g., 2023-10-27T10:00:00Z -> 2023-10-27 10:00:00)
            # Remove 'Z' and replace 'T' with space
            clean_created_at=$(echo "$created_at" | sed 's/T/ /' | sed 's/Z//')

            # Convert created_at to epoch time
            created_epoch=$(date -d "$clean_created_at" +%s)
            
            # Get current epoch time
            current_epoch=$(date +%s)

            # Calculate difference in seconds
            diff_seconds=$((current_epoch - created_epoch))

            # Calculate difference in days, hours, minutes, seconds
            diff_days=$((diff_seconds / 86400))
            remaining_seconds=$((diff_seconds % 86400))
            diff_hours=$((remaining_seconds / 3600))
            remaining_seconds=$((remaining_seconds % 3600))
            diff_minutes=$((remaining_seconds / 60))
            diff_seconds_final=$((remaining_seconds % 60))

            # Only show tunnels up to 365 days old
            if [ "$diff_days" -le 365 ]; then
                # Filter out disconnected tunnels older than 1 day
                if [[ -z "$connections" || "$connections" == "0" ]] && [ "$diff_days" -gt 1 ]; then
                    continue # Skip this tunnel
                fi

                # Determine the "tunnel link" - using NAME for now, prepending https://
                tunnel_link="https://${name}"

                # Build the time string
                time_string=""
                if [ "$diff_days" -gt 0 ]; then
                    time_string+="${diff_days} day"
                    [ "$diff_days" -ne 1 ] && time_string+="s"
                    time_string+=" "
                fi
                if [ "$diff_hours" -gt 0 ]; then
                    time_string+="${diff_hours} hour"
                    [ "$diff_hours" -ne 1 ] && time_string+="s"
                    time_string+=" "
                fi
                if [ "$diff_minutes" -gt 0 ]; then
                    time_string+="${diff_minutes} min"
                    [ "$diff_minutes" -ne 1 ] && time_string+="s"
                    time_string+=" "
                fi
                # Removed seconds as per user request
                # time_string+="${diff_seconds_final} sec"
                # [ "$diff_seconds_final" -ne 1 ] && time_string+="s"

                # Remove trailing space if any
                time_string=$(echo "$time_string" | sed 's/ *$//')

                # If time_string is empty (e.g., less than a minute), default to "just now" or "0 mins"
                if [ -z "$time_string" ]; then
                    time_string="0 mins"
                fi

                # Determine the color based on connections
                if [[ -z "$connections" || "$connections" == "0" ]]; then
                    # Red background and bold for disconnected tunnels
                    echo -e "\e[41m\e[1m${counter}) ${tunnel_link} (created ${time_string} ago) - DISCONNECTED\e[0m"
                else
                    # Green background and bold for connected tunnels
                    echo -e "\e[42m\e[1m${counter}) ${tunnel_link} (created ${time_string} ago)\e[0m"
                fi
                counter=$((counter+1))
            fi
        done
    fi
    exit 0
fi

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat_copy)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

cd "$PARENT_ABS_DIR"
export TUNNEL_ORIGIN_CERT=cert.pem
#echo $(pwd)

if [ ! -f "$TUNNEL_ORIGIN_CERT" ]; then
    echo -e "\e[31mError: TUNNEL_ORIGIN_CERT (cert.pem) is not found. Please ensure 'rat-cli login' has been run successfully.\e[0m"
    exit 1
fi
cleanup() {
    echo "Cleaning up..."
    pkill -P $$
    # rm -rf tunnels/${TUNNEL_NAME}
    # ./cloudflared-linux-amd64 tunnel delete ${TUNNEL_NAME}
    wait
    echo "Cleanup complete."
}

# Trap the EXIT signal and call the cleanup function
trap cleanup EXIT

if [ ! -n "$port" ]; then
    echo -e "\e[31mError: --port argument is required.\e[0m"
    usage
fi

if [ -n "$domain" ]; then

  TUNNEL_NAME=${domain}
  mkdir -p "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}

  ./cloudflared-linux-amd64 tunnel --credentials-file "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}/creds.json create ${TUNNEL_NAME}

  json_data=$(cat "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}/creds.json)
  tunnel_id=$(echo "$json_data" | grep -o '"TunnelID":"[^"]*' | cut -d'"' -f4)

  yaml_content="""tunnel: ${tunnel_id}
credentials-file: "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}/creds.json
ingress:
  - hostname: ${domain}
    service: ${protocol}://localhost:${port}
  - service: http_status:404
  """
  echo "$yaml_content" > "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}/config_${port}.yml
  ./cloudflared-linux-amd64 tunnel route dns ${tunnel_id} ${domain}
  if [ $? -ne 0 ]; then
    echo -e "\e[31mError: ${domain} is registered with another Tunnel ID. Please go to CloudFlare Dashboard and the delete the CNAME record to continue. Else you can use a different subdomain address.\e[0m"
    exit 1  # Exit with an error code
  fi
  date_time=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$date_time: $1 --> https://${domain}" >> host.log


  highlight_url "${protocol}://${domain}/${subpage_path}"
  echo -e "\e[33mCheck tunnel logs at: ${PARENT_ABS_DIR}/.logs/tunnel_${domain}_${port}.log\e[0m"

  ./cloudflared-linux-amd64 tunnel --config  "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}/config_${port}.yml run ${tunnel_id} &> .logs/tunnel_${domain}_${port}.log

else 

  log_file=".logs/tunnel_trycloudflare_${port}.log"
  rm -f "$log_file"

  ./cloudflared-linux-amd64 tunnel --url http://localhost:${port} --logfile "$log_file" &> .logs/tunnel_trycloudflare_${port}.log &

  sleep 1
  while :; do
      result=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' "$log_file")
      
      if [ -n "$result" ]; then
          highlight_url "$result"/$subpage_path
          echo -e "\e[33mCheck tunnel logs at: ${PARENT_ABS_DIR}/.logs/tunnel_trycloudflare_${port}.log\e[0m"
          break
      fi
      sleep 1
  done

  date_time=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$date_time: ${port} --> $result" >> host.log

  wait

fi
