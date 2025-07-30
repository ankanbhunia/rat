#!/bin/bash

# --- Configuration ---
VSCODE_EXTENSIONS="ms-python.python" # Comma-separated list of extensions

# --- Functions ---

# Function to display script usage
usage() {
    echo "Usage: $0 --version <VERSION> --arch <ARCHITECTURE> [OPTIONS]"
    echo "Downloads and installs the VSCode server (code-server) and specified extensions."
    echo ""
    echo "Options:"
    echo "  --version <VERSION>   The code-server version to download (e.g., 4.22.1). (Required)"
    echo "  --arch <ARCHITECTURE> The system architecture (e.g., linux-amd64, linux-arm64). (Required)"
    echo "  -h, --help            Display this help message and exit."
    echo ""
    echo "Steps:"
    echo "1. Downloads and extracts the code-server archive for the specified version and architecture."
    echo "2. Installs essential VSCode extensions (e.g., $VSCODE_EXTENSIONS)."
    echo "3. Cleans up the downloaded tarball."
    exit 0
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Logic ---

# Initialize variables for arguments
CODE_SERVER_VERSION=""
SYS_ARCH=""
help_flag=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            shift
            CODE_SERVER_VERSION="$1"
            ;;
        --arch)
            shift
            SYS_ARCH="$1"
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

echo "--- VSCode Server Installation Script ---"

# Check for required arguments
if [ -z "$CODE_SERVER_VERSION" ]; then
    echo "Error: --version argument is required."
    usage
fi

if [ -z "$SYS_ARCH" ]; then
    echo "Error: --arch argument is required."
    usage
fi

# 1. Check for curl
if ! command_exists "curl"; then
    echo "Error: 'curl' command not found. Please install curl (e.g., sudo apt-get install curl)."
    exit 1
fi

echo "Using code-server version: $CODE_SERVER_VERSION"
echo "Using system architecture: $SYS_ARCH"

# 2. Download code-server
DOWNLOAD_URL="https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-$SYS_ARCH.tar.gz"
TARBALL_NAME="code-server.tar.gz"

echo "Downloading code-server-$CODE_SERVER_VERSION-$SYS_ARCH.tar.gz..."
curl -fL "$DOWNLOAD_URL" > "$TARBALL_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download code-server from '$DOWNLOAD_URL'."
    exit 1
fi
echo "Download complete."

# 4. Extract code-server
echo "Extracting $TARBALL_NAME..."
tar -xvf "$TARBALL_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract '$TARBALL_NAME'."
    exit 1
fi
echo "Extraction complete."

# 5. Install essential VSCode extensions
echo "Installing VSCode extensions ($VSCODE_EXTENSIONS)..."
# Find the extracted code-server directory
CODE_SERVER_DIR=$(ls -d code-server-*/ 2>/dev/null | sort -V | tail -n 1)

if [ -z "$CODE_SERVER_DIR" ]; then
    echo "Error: Could not find extracted code-server directory. Extension installation skipped."
else
    "$CODE_SERVER_DIR/bin/code-server" --install-extension "$VSCODE_EXTENSIONS" --force --extensions-dir vscode-extensions_dir
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to install extensions. You might need to install them manually later."
    else
        echo "Extensions installed successfully."
    fi
fi

# 6. Clean up the tarball
echo "Cleaning up downloaded tarball..."
rm "$TARBALL_NAME"
echo "Cleanup complete."

echo "VSCode server installation finished."
