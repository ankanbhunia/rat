#!/bin/bash

# --- Default values ---
JUMPSERVER_DEFAULT="s2514643@daisy2.inf.ed.ac.uk"
JUMPSERVER=""
help_flag=false

# --- Functions ---

# Function to display script usage
usage() {
    echo "Usage: rat-cli proxy [OPTIONS]"
    echo "Description: Establishes an SSH tunnel to a specified jumpserver and starts a remote proxy server."
    echo "             This allows you to route your internet traffic through the jumpserver, effectively"
    echo "             using it as a VPN or for accessing resources behind a firewall."
    echo ""
    echo "Options:"
    echo "  --jumpserver <USER@HOST>  Specify the jumpserver (user@host) to connect to."
    echo "                            This server will host the proxy. (Default: $JUMPSERVER_DEFAULT)"
    echo "  -h, --help                Display this help message and exit."
    echo ""
    echo "Requirements:"
    echo "  - SSH client must be installed and configured to connect to the jumpserver."
    echo "  - A proxy server script (e.g., '~/.local/bin/proxy') must exist on the jumpserver."
    echo "  - The jumpserver must allow SSH connections and port forwarding."
    echo ""
    echo "Workflow:"
    echo "1. Sets up local HTTP/HTTPS proxy environment variables in your ~/.bashrc."
    echo "2. Establishes an SSH tunnel from your local machine to the jumpserver, forwarding a random"
    echo "   local port to a corresponding port on the jumpserver."
    echo "3. Executes the proxy server script on the jumpserver, binding it to the forwarded port."
    echo "4. Your local machine's traffic will then be routed through this tunnel and the remote proxy."
    echo ""
    echo "Examples:"
    echo "  rat-cli proxy"
    echo "  rat-cli proxy --jumpserver s2514643@vico02.inf.ed.ac.uk"
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --jumpserver)
            shift
            JUMPSERVER="$1"
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

# Use provided jumpserver or default
if [ -z "$JUMPSERVER" ]; then
    JUMPSERVER="$JUMPSERVER_DEFAULT"
fi

# --- Pre-flight Checks ---
if [ -z "$JUMPSERVER" ]; then
    echo "Error: No jumpserver specified and no default available."
    usage
fi

# Pick a pseudo-random port (no check)
RANDOM_PORT=$((20000 + RANDOM % 10000))
echo "Selected random port: $RANDOM_PORT"

# --- Cleanup Function (on script exit) ---
cleanup() {
    echo -e "\nCleaning up..."

    # Kill any leftover proxy on remote (in case it's detached)
    echo "Attempting to kill remote proxy on $JUMPSERVER for port $RANDOM_PORT..."
    ssh "$JUMPSERVER" "fuser -k $RANDOM_PORT/tcp 2>/dev/null"

    # Remove proxy exports from bashrc
    echo "Removing proxy environment variables from ~/.bashrc..."
    sed -i '/^export http_proxy=http:\/\/localhost:/d' ~/.bashrc
    sed -i '/^export https_proxy=http:\/\/localhost:/d' ~/.bashrc
    source ~/.bashrc # Reload bashrc to apply changes

    echo "Cleanup complete. Proxy environment variables removed."
    exit 0
}

# --- Trap signals for graceful exit ---
trap cleanup SIGINT SIGTERM EXIT

# Clean old proxy exports (before setting new ones)
echo "Cleaning old proxy environment variables from ~/.bashrc..."
sed -i.bak '/^export http_proxy=http:\/\/localhost:/d' ~/.bashrc
sed -i '/^export https_proxy=http:\/\/localhost:/d' ~/.bashrc

# Set proxy env
echo "Setting new proxy environment variables in ~/.bashrc..."
echo -e "export http_proxy=http://localhost:$RANDOM_PORT\nexport https_proxy=http://localhost:$RANDOM_PORT" >> ~/.bashrc
source ~/.bashrc # Reload bashrc to apply changes

# Start SSH tunnel and remote proxy in foreground
echo "Starting proxy server on $JUMPSERVER:$RANDOM_PORT"
echo "Establishing SSH tunnel..."
ssh -tt -L "$RANDOM_PORT:localhost:$RANDOM_PORT" "$JUMPSERVER" bash -l <<EOF
fuser -k $RANDOM_PORT/tcp 2>/dev/null
echo "Remote proxy started on port $RANDOM_PORT..."
~/.local/bin/proxy --port $RANDOM_PORT
EOF

# The script will wait here until the SSH tunnel is terminated (e.g., Ctrl+C)
# The trap function will then handle cleanup.
