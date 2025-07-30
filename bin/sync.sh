#!/bin/bash

# Default values
DIRECTION="upload" # Default direction is upload
JUMPSERVER=""

# Function to display help message
show_help() {
    echo "Usage: rat-cli sync <LOCAL_PATH> <REMOTE_PATH> [--jumpserver <user@host>] [--direction <upload/download>]"
    echo
    echo "Arguments:"
    echo "  LOCAL_PATH       The local file or folder path."
    echo "  REMOTE_PATH      The remote file or folder path (e.g., user@host:/path/to/remote)."
    echo
    echo "Options:"
    echo "  --jumpserver <user@host>  Optional jumpserver to use for SSH connection."
    echo "  --direction <upload/download>  Direction of synchronization (default: upload)."
    echo "  -h, --help       Show this help message and exit."
    echo
    echo "Examples:"
    echo "  rat-cli sync ./local_file.txt user@remote_host:/path/to/remote/"
    echo "  rat-cli sync user@remote_host:/path/to/remote/remote_file.txt ./local_dir/ --direction download"
    echo "  rat-cli sync ./local_project/ user@remote_host:/path/to/remote/ --jumpserver user@jump_host"
}

# Parse command-line arguments
LOCAL_PATH=""
REMOTE_PATH=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --jumpserver)
            JUMPSERVER="-J $2"
            shift
            ;;
        --direction)
            DIRECTION="$2"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$LOCAL_PATH" ]]; then
                LOCAL_PATH="$1"
            elif [[ -z "$REMOTE_PATH" ]]; then
                REMOTE_PATH="$1"
            fi
            ;;
    esac
    shift
done

# Validate arguments
if [[ -z "$LOCAL_PATH" || -z "$REMOTE_PATH" ]]; then
    echo "Error: Missing LOCAL_PATH or REMOTE_PATH."
    show_help
    exit 1
fi

# Construct rsync command
RSYNC_COMMAND="rsync -avz"

if [[ -n "$JUMPSERVER" ]]; then
    RSYNC_COMMAND+=" -e \"ssh $JUMPSERVER\""
else
    RSYNC_COMMAND+=" -e ssh"
fi

if [[ "$DIRECTION" == "upload" ]]; then
    RSYNC_COMMAND+=" \"$LOCAL_PATH\" \"$REMOTE_PATH\""
elif [[ "$DIRECTION" == "download" ]]; then
    RSYNC_COMMAND+=" \"$REMOTE_PATH\" \"$LOCAL_PATH\""
else
    echo "Error: Invalid direction '$DIRECTION'. Must be 'upload' or 'download'."
    show_help
    exit 1
fi

echo "Executing: $RSYNC_COMMAND"
eval $RSYNC_COMMAND

if [[ $? -eq 0 ]]; then
    echo "Synchronization successful."
else
    echo "Synchronization failed."
    exit 1
fi
