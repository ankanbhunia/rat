#!/bin/bash

# --- Global Variables for PIDs ---
VSCODE_PID=""
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
    if [ -n "$VSCODE_PID" ] && ps -p "$VSCODE_PID" > /dev/null; then
        echo "Terminating VSCode server (PID: $VSCODE_PID)..."
        kill "$VSCODE_PID"
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
# # Automatically select the most recent code-server directory
# echo "SCRIPT_ABS_DIR: $SCRIPT_ABS_DIR"
# echo "PARENT_ABS_DIR: $PARENT_ABS_DIR"

CODE_SERVER_FULL_PATH=$(ls -d "$PARENT_ABS_DIR"/code-server-*/ 2>/dev/null | sort -V | tail -n 1)
CODE_SERVER_FULL_PATH=${CODE_SERVER_FULL_PATH%/} # Remove trailing slash

# echo "CODE_SERVER_FULL_PATH: $CODE_SERVER_FULL_PATH"

if [ -z "$CODE_SERVER_FULL_PATH" ]; then
    echo "Error: No 'code-server-*' directory found in the parent folder."
    echo "Please ensure a code-server installation is present."
    exit 1
fi

CODE_SERVER_PATH="$CODE_SERVER_FULL_PATH/bin/code-server"
CLOUDFLARED_BIN="$PARENT_ABS_DIR/cloudflared-linux-amd64" # Define cloudflared path
CONFIG_FILE="$PARENT_ABS_DIR/config.yaml"
USER_DATA_DIR="$PARENT_ABS_DIR/vscode-user-dir"
EXTENSIONS_DIR="$PARENT_ABS_DIR/vscode-extensions_dir"
BIND_ADDR="127.0.0.1"

# echo "CODE_SERVER_PATH: $CODE_SERVER_PATH"
# echo "CLOUDFLARED_BIN: $CLOUDFLARED_BIN"
# echo "CONFIG_FILE: $CONFIG_FILE"
# echo "USER_DATA_DIR: $USER_DATA_DIR"
# echo "EXTENSIONS_DIR: $EXTENSIONS_DIR"

# --- Default values ---
jumpserver=""
port=""
domain=""
help_flag=false

# --- Functions ---

# Function to display script usage
usage() {
    echo "Usage: rat-cli vscode [OPTIONS]"
    echo "Description: Launches a VSCode server instance and optionally exposes it via a Cloudflare tunnel."
    echo "             This allows you to access your VSCode environment remotely through a web browser."
    echo ""
    echo "Options:"
    echo "  --port <PORT>          Specify a specific local port for the VSCode server to listen on."
    echo "                         If not provided, a random port between 7000-7999 will be used."
    echo "  --jumpserver <USER@HOST> Specify a jumpserver for establishing a reverse SSH tunnel."
    echo "                         This is useful if direct port exposure is blocked. Mutually exclusive with --domain."
    echo "  --domain <DOMAIN>      Specify a custom domain for the Cloudflare tunnel (e.g., myvscode.runs.space)."
    echo "                         Requires prior Cloudflare domain setup and 'rat-cli login'. Mutually exclusive with --jumpserver."
    echo "  -h, --help             Display this help message and exit."
    echo ""
    echo "Requirements:"
    echo "  - A 'code-server-*' installation must be present in the 'rat' directory."
    echo "  - 'cloudflared-linux-amd64' executable must be present in the 'rat' directory."
    echo "  - 'rat-cli login' must have been run successfully if using --domain."
    echo "  - SSH client must be installed if using --jumpserver."
    echo ""
    echo "Workflow:"
    echo "1. Starts the VSCode server on a specified or random local port."
    echo "2. Based on provided options, it sets up a Cloudflare tunnel:"
    echo "   - If --jumpserver is used, it creates a reverse SSH tunnel to the jumpserver."
    echo "   - If --domain is used, it creates a direct Cloudflare tunnel to the specified domain."
    echo "   - If neither is specified, it creates a temporary Cloudflare tunnel with a random trycloudflare.com URL."
    echo "3. The script will keep the VSCode server and tunnel running in the foreground until terminated."
    echo ""
    echo "Examples:"
    echo "  rat-cli vscode"
    echo "  rat-cli vscode --port 8080"
    echo "  rat-cli vscode --jumpserver user@jumpserver.example.com"
    echo "  rat-cli vscode --domain myvscode.runs.space"
    echo "  rat-cli vscode --jumpserver user@jumpserver.example.com --port 8080"
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
# No need to change directory here, as all paths are now absolute
# CURPATH="$(dirname "$0")"
# cd "$CURPATH" || { echo "Error: Could not change to script directory."; exit 1; }

if [ ! -f "$CODE_SERVER_PATH" ]; then
    echo "Error: VSCode server executable not found at '$CODE_SERVER_PATH'."
    echo "Please ensure the selected 'code-server-*' directory contains 'bin/code-server'."
    exit 1
fi

if [ ! -f "$CLOUDFLARED_BIN" ]; then
    echo "Error: Cloudflared executable not found at '$CLOUDFLARED_BIN'."
    echo "Please ensure 'cloudflared-linux-amd64' is in the parent directory."
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

# --- Start VSCode Server ---
echo "Starting VSCode server on $BIND_ADDR:$PORT..."
# The VSCODE_IPC_HOOK_CLI variable is intentionally left empty as per original script.
# Redirecting output to /dev/null to keep the terminal clean.
VSCODE_IPC_HOOK_CLI= "$CODE_SERVER_PATH" --config "$CONFIG_FILE" --user-data-dir "$USER_DATA_DIR" --extensions-dir "$EXTENSIONS_DIR" --bind-addr "$BIND_ADDR:$PORT" >> /dev/null 2>&1 &
VSCODE_PID=$!
sleep 2 # Give code-server a moment to start

if ! ps -p "$VSCODE_PID" > /dev/null; then
    echo "Error: VSCode server failed to start."
    exit 1
fi
echo "VSCode server started with PID $VSCODE_PID."

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

echo "Script finished. VSCode server and tunnel (if applicable) are running in the foreground."
echo "They will be automatically terminated upon script exit."
echo "You can check 'host.log' or 'cloudflare_log' for tunnel status if applicable."
