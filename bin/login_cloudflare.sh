#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat_copy)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

# --- Configuration ---
CLOUDFLARED_BIN="$PARENT_ABS_DIR/cloudflared-linux-amd64"
CERT_DIR="$HOME/.cloudflared"
TARGET_CERT_FILE="$PARENT_ABS_DIR/cert.pem" # As requested by the user

# --- Functions ---

# Function to display script usage
usage() {
    echo "Usage: rat-cli login [OPTIONS]"
    echo "Description: Logs into Cloudflare and manages the authentication certificate."
    echo "             This command initiates the Cloudflare tunnel login process, which requires"
    echo "             browser interaction for authentication. Upon successful login, it copies"
    echo "             the generated certificate to the 'rat' directory for subsequent use."
    echo ""
    echo "Options:"
    echo "  -h, --help    Display this help message and exit."
    echo ""
    echo "Requirements:"
    echo "  - The 'cloudflared-linux-amd64' executable must be present in the 'rat' directory."
    echo "  - An active internet connection is required for Cloudflare authentication."
    echo ""
    echo "Workflow:"
    echo "1. Executes 'cloudflared tunnel login', which will automatically open a browser window."
    echo "2. You must complete the authentication process in your browser."
    echo "3. After successful authentication, the script locates the generated certificate"
    echo "   (e.g., 'cert.pem' or 'cert.json') from '$CERT_DIR'."
    echo "4. The located certificate is then copied to '$TARGET_CERT_FILE' in the 'rat' directory."
    echo ""
    echo "Example:"
    echo "  rat-cli login"
    exit 0
}

# Function to check if a command/file exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Logic ---

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

echo "--- Cloudflare Login Script ---"

# 1. Check if cloudflared executable exists
if [ ! -f "$CLOUDFLARED_BIN" ]; then
    echo "Error: Cloudflare daemon executable not found at '$CLOUDFLARED_BIN'."
    echo "Please ensure 'cloudflared-linux-amd64' is in the parent directory."
    exit 1
fi

# 2. Run cloudflared tunnel login
echo "Attempting to log in to Cloudflare. This will open a browser window for authentication."
echo "Please follow the instructions in your browser to complete the login."
"$CLOUDFLARED_BIN" tunnel login

# Check the exit status of the last command
if [ $? -ne 0 ]; then
    echo "Error: Cloudflare login failed. Please check your internet connection and Cloudflare account."
    exit 1
fi

echo "Cloudflare login successful."

# 3. Locate and copy the certificate file
echo "Searching for generated certificate in '$CERT_DIR'..."

# Prioritize cert.pem if it exists, otherwise look for cert.json
GENERATED_CERT=""
if [ -f "$CERT_DIR/cert.pem" ]; then
    GENERATED_CERT="$CERT_DIR/cert.pem"
elif [ -f "$CERT_DIR/cert.json" ]; then
    GENERATED_CERT="$CERT_DIR/cert.json"
fi

if [ -n "$GENERATED_CERT" ]; then
    echo "Found certificate: '$GENERATED_CERT'."
    echo "Copying to '$TARGET_CERT_FILE'..."
    cp "$GENERATED_CERT" "$TARGET_CERT_FILE"
    if [ $? -eq 0 ]; then
        echo "Certificate copied successfully to '$TARGET_CERT_FILE'."
    else
        echo "Error: Failed to copy certificate to '$TARGET_CERT_FILE'."
        exit 1
    fi
else
    echo "Warning: No 'cert.pem' or 'cert.json' found in '$CERT_DIR' after login."
    echo "The certificate might have a different name or location, or the login process did not generate one."
    echo "Please manually locate and copy the correct certificate file if needed."
    exit 1
fi

echo "Script finished."
