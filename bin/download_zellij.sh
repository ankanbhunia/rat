#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

ZELLIJ_BIN="$PARENT_ABS_DIR/zellij"

# Function to display script usage
usage() {
    echo "Usage: $0 [--version <VERSION>] [--arch <ARCHITECTURE>]"
    echo "Downloads and installs the Zellij multiplexer executable."
    echo ""
    echo "Options:"
    echo "  --version <VERSION>   (Optional) The Zellij version to download (e.g., 0.40.0)."
    echo "                        If not provided, the latest stable version will be downloaded."
    echo "  --arch <ARCHITECTURE> (Optional) The system architecture (e.g., x86_64-unknown-linux-musl, aarch64-unknown-linux-musl)."
    echo "                        If not provided, defaults to 'x86_64-unknown-linux-musl'."
    echo "  -h, --help            Display this help message and exit."
    echo ""
    echo "Example:"
    echo "  bash ./bin/download_zellij.sh"
    echo "  bash ./bin/download_zellij.sh --version 0.40.0 --arch x86_64-unknown-linux-musl"
    exit 0
}

# Initialize variables for arguments
ZELLIJ_VERSION=""
ZELLIJ_ARCH="x86_64-unknown-linux-musl" # Default architecture
help_flag=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            shift
            ZELLIJ_VERSION="$1"
            ;;
        --arch)
            shift
            ZELLIJ_ARCH="$1"
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

echo "--- Zellij Download Script ---"

# Determine the version if not provided
if [ -z "$ZELLIJ_VERSION" ]; then
    echo "No version specified. Fetching the latest stable version..."
    # NOTE: Due to environment limitations, I cannot directly fetch the latest release tag.
    # This part assumes the GitHub API call would work similarly to cloudflared.
    # You might need to manually verify the latest tag and adjust the script if this fails.
    LATEST_RELEASE_TAG=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | grep "tag_name" | cut -d : -f 2,3 | tr -d \"\, | head -n 1 | awk '{$1=$1};1')
    if [ -z "$LATEST_RELEASE_TAG" ]; then
        echo -e "\e[31mError: Could not determine the latest Zellij version. Please check your internet connection or the GitHub API.\e[0m"
        exit 1
    fi
    ZELLIJ_VERSION="$LATEST_RELEASE_TAG"
    echo "Latest version found: $ZELLIJ_VERSION"
fi

echo "Using Zellij version: $ZELLIJ_VERSION"
echo "Using system architecture: $ZELLIJ_ARCH"

# Construct the download URL
# Zellij releases are typically packaged as .tar.gz files, e.g., zellij-x86_64-unknown-linux-musl.tar.gz
ZELLIJ_DOWNLOAD_URL="https://github.com/zellij-org/zellij/releases/download/$ZELLIJ_VERSION/zellij-$ZELLIJ_ARCH.tar.gz"
TEMP_TAR_GZ="/tmp/zellij-$ZELLIJ_ARCH.tar.gz"

echo "Downloading Zellij from $ZELLIJ_DOWNLOAD_URL..."
curl -L -o "$TEMP_TAR_GZ" "$ZELLIJ_DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to download Zellij from '$ZELLIJ_DOWNLOAD_URL'. Please check your internet connection or the download URL.\e[0m"
    exit 1
fi
echo "Zellij archive downloaded to $TEMP_TAR_GZ."

echo "Extracting Zellij..."
tar -xzf "$TEMP_TAR_GZ" -C "$PARENT_ABS_DIR"
if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to extract Zellij archive.\e[0m"
    exit 1
fi

chmod +x "$ZELLIJ_BIN"
if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to make zellij executable.\e[0m"
    exit 1
fi

rm "$TEMP_TAR_GZ"
echo "zellij downloaded, extracted, and made executable at $ZELLIJ_BIN."
