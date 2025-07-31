#!/bin/bash

port=""
domain=""
subpage_path=""
protocol="http"
help_flag=false

# Function to display script usage
usage() {
    echo "Usage: rat-cli tunnel --port <PORT> [OPTIONS]"
    echo "Description: Creates a Cloudflare tunnel to expose a local port to the internet."
    echo "             This can be used to share local services or make a machine SSH-accessible."
    echo ""
    echo "Options:"
    echo "  --port <PORT>         The local port to expose. (Required)"
    echo "  --domain <DOMAIN>     (Optional) A custom domain to use for the tunnel (e.g., myapp.runs.space)."
    echo "                        Requires prior Cloudflare domain setup and 'rat-cli login'."
    echo "  --subpage_path <PATH> (Optional) A path to append to the tunnel URL (e.g., for sharing a specific file)."
    echo "  --protocol <PROTOCOL> (Optional) The protocol for the tunnel service (e.g., http, ssh). Default: http"
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

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat_copy)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

cd "$PARENT_ABS_DIR"
export TUNNEL_ORIGIN_CERT=cert.pem
echo $(pwd)

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

  "$PARENT_ABS_DIR"/cloudflared-linux-amd64 tunnel --credentials-file "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}/creds.json create ${TUNNEL_NAME}

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
  "$PARENT_ABS_DIR"/cloudflared-linux-amd64 tunnel route dns ${tunnel_id} ${domain}
  if [ $? -ne 0 ]; then
    echo -e "\e[31mError: ${domain} is registered with another Tunnel ID. Please go to CloudFlare Dashboard and the delete the CNAME record to continue. Else you can use a different subdomain address.\e[0m"
    exit 1  # Exit with an error code
  fi
  date_time=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$date_time: $1 --> https://${domain}" >> host.log

  highlight_url() {
      echo -e "\e[34m$1\e[0m"
  }
  echo '###############################'
  echo $(highlight_url "https://${domain}/${subpage_path}")
  echo '###############################'

  "$PARENT_ABS_DIR"/cloudflared-linux-amd64 tunnel --config  "$PARENT_ABS_DIR"/tunnels/${TUNNEL_NAME}/config_${port}.yml run ${tunnel_id}

else 

  log_file=cloudflare_log
  rm -f "$log_file"

  "$PARENT_ABS_DIR"/cloudflared-linux-amd64 tunnel --url http://localhost:${port} --logfile cloudflare_log  >> /dev/null 2>&1 &

  sleep 1
  while :; do
      result=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' "$log_file")
      
      if [ -n "$result" ]; then
          echo "$result"/$subpage_path
          break
      fi
      sleep 1
  done

  date_time=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$date_time: ${port} --> $result" >> host.log

  wait

fi
