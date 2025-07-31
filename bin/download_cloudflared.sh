#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

CLOUDFLARED_BIN="$PARENT_ABS_DIR/cloudflared-linux-amd64"

if [ ! -f "$CLOUDFLARED_BIN" ]; then
    echo "cloudflared-linux-amd64 not found. Attempting to download the latest version..."
    CLOUDFLARED_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep "browser_download_url" | grep "cloudflared-linux-amd64\"" | sed -n 's/.*"\(https:\/\/github\.com\/cloudflare\/cloudflared\/releases\/download\/[^\"]*\)".*/\1/p' | head -n 1)

    if [ -z "$CLOUDFLARED_DOWNLOAD_URL" ]; then
        echo -e "\e[31mError: Could not determine the latest cloudflared-linux-amd64 download URL. Please check your internet connection or the GitHub API.\e[0m"
        exit 1
    fi

    echo "Downloading cloudflared-linux-amd64 from $CLOUDFLARED_DOWNLOAD_URL..."
    curl -L -o "$CLOUDFLARED_BIN" "$CLOUDFLARED_DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "\e[31mError: Failed to download cloudflared-linux-amd64. Please check your internet connection or the download URL.\e[0m"
        exit 1
    fi
    chmod +x "$CLOUDFLARED_BIN"
    if [ $? -ne 0 ]; then
        echo -e "\e[31mError: Failed to make cloudflared-linux-amd64 executable.\e[0m"
        exit 1
    fi
    echo "cloudflared-linux-amd64 downloaded and made executable."
else
    echo "cloudflared-linux-amd64 already exists."
fi
