#!/bin/bash

DOMAIN="lonelycoder.live"
TUNNEL="8458a8db-b11e-4b65-a631-18786e567570"

CURPATH="$(dirname "$0")"
cd $CURPATH

echo $(pwd)


if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <host> <port>"
    exit 1
fi

host="$1"
port="$2"

cleanup() {
    echo "Cleaning up..."
    pkill -P $$
    rm configs/config_${host}_${port}.yml
    wait
    echo "Cleanup complete."
}

# Trap the EXIT signal and call the cleanup function
trap cleanup EXIT

yaml_content="tunnel: ${TUNNEL}
credentials-file: ${TUNNEL}.json

ingress:
  - hostname: ${host}.${DOMAIN}
    service: http://localhost:${port}
  - service: http_status:404
"
mkdir -p "configs"
./cloudflared-linux-amd64 tunnel route dns ${TUNNEL} ${host}.${DOMAIN}
echo "$yaml_content" > configs/config_${host}_${port}.yml
./cloudflared-linux-amd64 tunnel --config configs/config_${host}_${port}.yml run ${TUNNEL}