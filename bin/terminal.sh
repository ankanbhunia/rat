#!/bin/bash

# --- Global Variables for PIDs ---
ZELLIJ_PID=""
SSH_PID=""
TUNNEL_PID=""

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat_copy)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

# --- Cleanup Function ---
cleanup() {
    echo ""
    echo "Shutting down processes..."
    if [ -n "$ZELLIJ_PID" ] && ps -p "$ZELLIJ_PID" > /dev/null; then
        echo "Terminating Zellij web client (PID: $ZELLIJ_PID)..."
        kill "$ZELLIJ_PID"
    fi
    if [ -n "$SSH_PID" ] && ps -p "$SSH_PID" > /dev/null; then
        echo "Terminating SSH tunnel (PID: $SSH_PID)..."
        kill "$SSH_PID"
    fi
    if [ -n "$TUNNEL_PID" ] && ps -p "$TUNNEL_PID" > /dev/null; then
        echo "Terminating local tunnel (PID: $TUNNEL_PID)..."
        kill "$TUNNEL_PID"
    fi
    echo "Cleanup complete."
    exit 0
}

# --- Trap signals for graceful exit ---
trap cleanup SIGINT SIGTERM SIGHUP EXIT

# --- Configuration ---
CLOUDFLARED_BIN="$PARENT_ABS_DIR/cloudflared-linux-amd64" # Define cloudflared path
BIND_ADDR="127.0.0.1"

echo "CLOUDFLARED_BIN: $CLOUDFLARED_BIN"

# --- Default values ---
jumpserver=""
port=""
domain=""
help_flag=false

# --- Functions ---

# Function to display script usage
usage() {
    echo "Usage: rat-cli terminal [OPTIONS]"
    echo "Description: Launches a Zellij web client instance and optionally exposes it via a Cloudflare tunnel."
    echo "             This allows you to access your Zellij terminal remotely through a web browser."
    echo ""
    echo "Options:"
    echo "  --port <PORT>          Specify a specific local port for the Zellij web client to listen on."
    echo "                         If not provided, a random port between 7000-7999 will be used."
    echo "  --jumpserver <USER@HOST> Specify a jumpserver for establishing a reverse SSH tunnel."
    echo "                         This is useful if direct port exposure is blocked. Mutually exclusive with --domain."
    echo "  --domain <DOMAIN>      Specify a custom domain for the Cloudflare tunnel (e.g., myterminal.runs.space)."
    echo "                         Requires prior Cloudflare domain setup and 'rat-cli login'. Mutually exclusive with --jumpserver."
    echo "  -h, --help             Display this help message and exit."
    echo ""
    echo "Requirements:"
    echo "  - 'zellij' executable must be present globally or in the 'rat' directory."
    echo "  - 'cloudflared-linux-amd64' executable must be present in the 'rat' directory."
    echo "  - 'rat-cli login' must have been run successfully if using --domain."
    echo "  - SSH client must be installed if using --jumpserver."
    echo ""
    echo "Workflow:"
    echo "1. Starts the Zellij web client on a specified or random local port."
    echo "2. Based on provided options, it sets up a Cloudflare tunnel:"
    echo "   - If --jumpserver is used, it creates a reverse SSH tunnel to the jumpserver."
    echo "   - If --domain is used, it creates a direct Cloudflare tunnel to the specified domain."
    echo "   - If neither is specified, it creates a temporary Cloudflare tunnel with a random trycloudflare.com URL."
    echo "3. The script will keep the Zellij web client and tunnel running in the foreground until terminated."
    echo ""
    echo "Examples:"
    echo "  rat-cli terminal"
    echo "  rat-cli terminal --port 8080"
    echo "  rat-cli terminal --jumpserver user@jumpserver.example.com"
    echo "  rat-cli terminal --domain myterminal.runs.space"
    echo "  rat-cli terminal --jumpserver user@jumpserver.example.com --port 8080"
    exit 0
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --jumpserver)
            shift
            jumpserver="$1"
            ;;
        --port)
            shift
            if ! [[ "$1" =~ ^[0-9]+$ ]]; then
                echo "Error: Port must be a number."
                usage
            fi
            port="$1"
            ;;
        --domain)
            shift
            domain="$1"
            ;;
        -h|--help)
            help_flag=true
            ;;
        *)
            echo "Error: Unknown option '$1'"
            usage
            ;;
    esac
    shift
done

if "$help_flag"; then
    usage
fi

# --- Pre-flight Checks ---
if [ ! -f "$CLOUDFLARED_BIN" ]; then
    echo "Error: Cloudflared executable not found at '$CLOUDFLARED_BIN'."
    echo "Please ensure 'cloudflared-linux-amd64' is in the parent directory."
    exit 1
fi

# Determine Zellij command path
ZELLIJ_LOCAL_PATH="$PARENT_ABS_DIR/zellij"
ZELLIJ_CMD=""

if command -v zellij &> /dev/null; then
    ZELLIJ_CMD="zellij"
elif [ -f "$ZELLIJ_LOCAL_PATH" ]; then
    ZELLIJ_CMD="$ZELLIJ_LOCAL_PATH"
else
    echo "Error: Zellij executable not found globally or at '$ZELLIJ_LOCAL_PATH'."
    echo "Please ensure Zellij is installed or run 'rat-cli zj' to download it."
    exit 1
fi

# --- Determine Port ---
if [ -z "$port" ]; then
    PORT=$(($RANDOM%1000+7000))
    echo "No port specified. Using random port: $PORT"
else
    PORT="$port"
    echo "Using specified port: $PORT"
fi

# --- Start Zellij Web Client ---
echo "Starting Zellij web client on $BIND_ADDR:$PORT..."
ZELLIJ_SOCKET_DIR=/tmp/zellij "$ZELLIJ_CMD" web --port "$PORT"  >> /dev/null 2>&1 &
ZELLIJ_PID=$!
sleep 2 # Give zellij a moment to start

if ! ps -p "$ZELLIJ_PID" > /dev/null; then
    echo "Error: Zellij web client failed to start."
    exit 1
fi
echo "Zellij web client started with PID $ZELLIJ_PID."

# --- Setup Tunnel ---
if [ -n "$jumpserver" ]; then
    echo "Attempting to establish reverse tunnel via $jumpserver for port $PORT..."
    if ! command_exists "ssh"; then
        echo "Error: 'ssh' command not found. Please install OpenSSH client."
        exit 1
    fi
    # Assuming the remote tunnel script path is fixed as per original script
    ssh -R "${PORT}:localhost:${PORT}" "$jumpserver" "rat-cli tunnel --port ${PORT} --domain ${domain}"
    SSH_PID=$!
    echo "SSH tunnel initiated with PID $SSH_PID. Check SSH logs for connection status."
elif [ -n "$domain" ]; then
    echo "Starting tunnel for domain $domain on port $PORT..."
    "$SCRIPT_ABS_DIR"/tunnel.sh --domain "${domain}" --port "${PORT}"
    TUNNEL_PID=$!
    echo "Tunnel initiated with PID $TUNNEL_PID."
else
    echo "Starting tunnel for port $PORT (no domain specified)..."
    "$SCRIPT_ABS_DIR"/tunnel.sh --port "${PORT}"
    TUNNEL_PID=$!
    echo "Tunnel initiated with PID $TUNNEL_PID."
fi

echo "Script finished. Zellij web client and tunnel (if applicable) are running in the foreground."
echo "They will be automatically terminated upon script exit."
echo "You can check 'host.log' or 'cloudflare_log' for tunnel status if applicable."
