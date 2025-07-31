#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

CLOUDFLARED_BIN="$PARENT_ABS_DIR/cloudflared-linux-amd64"

# Function to display script usage
usage() {
    echo "Usage: $0 [--version <VERSION>] [--arch <ARCHITECTURE>]"
    echo "Downloads and installs the Cloudflare Tunnel (cloudflared) executable."
    echo ""
    echo "Options:"
    echo "  --version <VERSION>   (Optional) The cloudflared version to download (e.g., 2025.7.0)."
    echo "                        If not provided, the latest stable version will be downloaded."
    echo "  --arch <ARCHITECTURE> (Optional) The system architecture (e.g., linux-amd64, linux-arm64)."
    echo "                        If not provided, defaults to 'linux-amd64'."
    echo "  -h, --help            Display this help message and exit."
    echo ""
    echo "Example:"
    echo "  bash ./bin/download_cloudflared.sh"
    echo "  bash ./bin/download_cloudflared.sh --version 2025.7.0 --arch linux-amd64"
    exit 0
}

# Initialize variables for arguments
CLOUDFLARED_VERSION=""
CLOUDFLARED_ARCH="linux-amd64" # Default architecture
help_flag=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            shift
            CLOUDFLARED_VERSION="$1"
            ;;
        --arch)
            shift
            CLOUDFLARED_ARCH="$1"
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

echo "--- Cloudflared Download Script ---"

# Determine the version if not provided
if [ -z "$CLOUDFLARED_VERSION" ]; then
    echo "No version specified. Fetching the latest stable version..."
    LATEST_RELEASE_TAG=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep "tag_name" | cut -d : -f 2,3 | tr -d \"\, | head -n 1 | awk '{$1=$1};1')
    if [ -z "$LATEST_RELEASE_TAG" ]; then
        echo -e "\e[31mError: Could not determine the latest cloudflared version. Please check your internet connection or the GitHub API.\e[0m"
        exit 1
    fi
    CLOUDFLARED_VERSION="$LATEST_RELEASE_TAG"
    echo "Latest version found: $CLOUDFLARED_VERSION"
fi

echo "Using cloudflared version: $CLOUDFLARED_VERSION"
echo "Using system architecture: $CLOUDFLARED_ARCH"

# Construct the download URL
CLOUDFLARED_DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/download/$CLOUDFLARED_VERSION/cloudflared-$CLOUDFLARED_ARCH"

echo "Downloading cloudflared from $CLOUDFLARED_DOWNLOAD_URL..."
curl -L -o "$CLOUDFLARED_BIN" "$CLOUDFLARED_DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to download cloudflared from '$CLOUDFLARED_DOWNLOAD_URL'. Please check your internet connection or the download URL.\e[0m"
    exit 1
fi
chmod +x "$CLOUDFLARED_BIN"
if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to make cloudflared-linux-amd64 executable.\e[0m"
    exit 1
fi
echo "cloudflared-linux-amd64 downloaded and made executable."
