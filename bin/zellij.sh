#!/bin/bash

# Get the absolute path of the current script's directory's parent
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
ZELLIJ_PATH="$SCRIPT_ABS_DIR/zellij"

# Check if zellij exists globally or in the rat directory
if ! command -v zellij &> /dev/null && [ ! -f "$ZELLIJ_PATH" ]; then
    echo "Zellij not found. Downloading the latest version..."
    
    # Get the latest version URL for x86_64 linux musl
    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | grep "browser_download_url.*zellij-x86_64-unknown-linux-musl.tar.gz" | cut -d '"' -f 4)
    
    if [ -z "$LATEST_RELEASE_URL" ]; then
        echo "Could not find the latest release URL for zellij."
        # Fallback to the version specified by the user
        LATEST_RELEASE_URL="https://github.com/zellij-org/zellij/releases/download/v0.42.2/zellij-x86_64-unknown-linux-musl.tar.gz"
        echo "Falling back to $LATEST_RELEASE_URL"
    fi

    echo "Downloading from $LATEST_RELEASE_URL"
    wget -q --show-progress -O /tmp/zellij.tar.gz "$LATEST_RELEASE_URL"
    
    if [ $? -ne 0 ]; then
        echo "Failed to download zellij."
        exit 1
    fi

    tar -xzf /tmp/zellij.tar.gz -C "$SCRIPT_ABS_DIR"
    
    if [ $? -ne 0 ]; then
        echo "Failed to extract zellij."
        exit 1
    fi
    
    rm /tmp/zellij.tar.gz
    chmod +x "$ZELLIJ_PATH"
    echo "Zellij installed successfully to $ZELLIJ_PATH"
fi

# Determine which zellij to run
if command -v zellij &> /dev/null; then
    ZELLIJ_CMD="zellij"
elif [ -f "$ZELLIJ_PATH" ]; then
    ZELLIJ_CMD="$ZELLIJ_PATH"
else
    echo "Zellij is not installed and the download failed. Please install it manually."
    exit 1
fi

# Run zellij with all arguments
exec $ZELLIJ_CMD "$@"
