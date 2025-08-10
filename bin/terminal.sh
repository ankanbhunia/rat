#!/bin/bash

# --- Global Variables for PIDs ---
ZELLIJ_PID=""
SSH_PID=""
TUNNEL_PID=""

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat_copy)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

# --- Token File Path ---
ZELLIJ_TOKEN_FILE="$PARENT_ABS_DIR/token.pem"

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


# --- Default values ---
jumpserver=""
port=""
domain=""
help_flag=false
renew_token_flag=false
show_token_flag=false

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
    echo "  --renew-token          Generate a new Zellij web token and save it to the token file."
    echo "  --show-token           Display the current Zellij web token."
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
    echo "  rat-cli terminal --renew-token"
    echo "  rat-cli terminal --show-token"
    exit 0
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display text in a dotted box
display_in_box() {
    local text="$1"
    local len=${#text}
    local border_len=$((len + 4)) # 2 spaces on each side
    local horizontal_line=$(printf '─%.0s' $(seq 1 $border_len))
    local dotted_line=$(printf '─%.0s' $(seq 1 $border_len) | sed 's/─/─ /g' | cut -c 1-$border_len)

    echo ""
    echo "┌$horizontal_line┐"
    echo "│  $text  │"
    echo "└$horizontal_line┘"
    echo ""
}

# Function to handle Zellij web token
handle_zellij_token() {
    local zellij_cmd="$1"
    local current_token=""

    if [ -f "$ZELLIJ_TOKEN_FILE" ] && [ "$renew_token_flag" = false ]; then
        current_token=$(cat "$ZELLIJ_TOKEN_FILE")
    else
        # Ensure the directory for the token file exists
        mkdir -p "$(dirname "$ZELLIJ_TOKEN_FILE")"
        
        # Create a new token and capture the output
        local token_output=$("$zellij_cmd" web --create-token 2>&1)
        
        # Extract the token (assuming it's the last line after "token_X: ")
        new_token=$(echo "$token_output" | grep -oP 'token_[0-9]+: \K[a-f0-9-]+' | tail -n 1)
        
        if [ -n "$new_token" ]; then
            echo "$new_token" > "$ZELLIJ_TOKEN_FILE"
            chmod 600 "$ZELLIJ_TOKEN_FILE" # Set secure permissions
            current_token="$new_token"
        else
            echo "Error: Failed to create Zellij web token. Output: $token_output"
            exit 1
        fi
    fi
    echo "$current_token" # Return the token
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
        --renew-token)
            renew_token_flag=true
            ;;
        --show-token)
            show_token_flag=true
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

# Handle Zellij token (create/renew/display)
ZELLIJ_WEB_TOKEN=$(handle_zellij_token "$ZELLIJ_CMD")

# Display the token in a box

# If only renewing token, exit after handling
if [ "$renew_token_flag" = true ]; then
    echo "Token renewal complete. Exiting."
    exit 0
fi

# If only showing token, display it and exit
if [ "$show_token_flag" = true ]; then
    display_in_box "$ZELLIJ_WEB_TOKEN"
    exit 0
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


mkdir -p "/dev/shm/zellij-$USER"

ZELLIJ_SOCKET_DIR="/dev/shm/zellij-$USER" "$ZELLIJ_CMD" web --port "$PORT" >> /dev/null 2>&1 &
ZELLIJ_PID=$!
sleep 2 # Give zellij a moment to start

if ! ps -p "$ZELLIJ_PID" > /dev/null; then
    echo "Error: Zellij web client failed to start."
    exit 1
fi
echo "Zellij web client started with PID $ZELLIJ_PID."

display_in_box "$ZELLIJ_WEB_TOKEN"

# --- Setup Tunnel ---

# --- Setup Tunnel ---
if [ -n "$jumpserver" ]; then
    echo "Attempting to establish reverse tunnel via $jumpserver for port $PORT..."
    if ! command_exists "ssh"; then
        echo "Error: 'ssh' command not found. Please install OpenSSH client."
        exit 1
    fi
    # Assuming the remote tunnel script path is fixed as per original script
    # If no domain is specified with jumpserver, generate a random one
    if [ -z "$domain" ]; then
        source "$PARENT_ABS_DIR"/bin/random_domain_generator.sh
        generated_domain=$(generate_random_domain "${PARENT_ABS_DIR}/cert.pem" terminal)
        if [ $? -eq 0 ] && [ -n "$generated_domain" ]; then
            echo "Generated random domain for jumpserver tunnel: $generated_domain"
            domain="$generated_domain" # Use the generated domain
            ssh -R "${PORT}:localhost:${PORT}" "$jumpserver" "rat-cli tunnel --port ${PORT} --domain ${domain} --subpage_path $(hostname -s)"
            SSH_PID=$!
        else
            echo "Warning: Random domain generation failed or returned empty for jumpserver tunnel. Proceeding without a specific domain."
            ssh -R "${PORT}:localhost:${PORT}" "$jumpserver" "rat-cli tunnel --port ${PORT} --subpage_path $(hostname -s)"
        fi
    else
        ssh -R "${PORT}:localhost:${PORT}" "$jumpserver" "rat-cli tunnel --port ${PORT} --domain ${domain} --subpage_path $(hostname -s)"

    fi

    # Assuming the remote tunnel script path is fixed as per original script

    echo "SSH tunnel initiated with PID $SSH_PID. Check SSH logs for connection status."
elif [ -n "$domain" ]; then
    echo "Starting tunnel for domain $domain on port $PORT..."
    "$SCRIPT_ABS_DIR"/tunnel.sh --domain "${domain}" --port "${PORT}" --subpage_path $(hostname -s)
    TUNNEL_PID=$!
    echo "Tunnel initiated with PID $TUNNEL_PID."
else
    source "$PARENT_ABS_DIR"/bin/random_domain_generator.sh
    domain=$(generate_random_domain "${PARENT_ABS_DIR}/cert.pem" terminal)
    if [ $? -eq 0 ] && [ -n "$domain" ]; then
        echo "Starting tunnel for port $PORT with generated domain: $domain..."
        "$SCRIPT_ABS_DIR"/tunnel.sh --domain "${domain}" --port "${PORT}" --subpage_path $(hostname -s)
    else
        echo "Starting tunnel for port $PORT (no domain specified, random domain generation failed or returned empty)..."
        "$SCRIPT_ABS_DIR"/tunnel.sh --port "${PORT}" --subpage_path $(hostname -s)
    fi
    TUNNEL_PID=$!
    echo "Tunnel initiated with PID $TUNNEL_PID."
fi

echo "Script finished. terminal server and tunnel (if applicable) are running in the foreground."
echo "They will be automatically terminated upon script exit."
echo "You can check 'host.log' or 'cloudflare_log' for tunnel status if applicable."
