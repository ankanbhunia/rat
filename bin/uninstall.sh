#!/bin/bash

# Get the absolute path of the rat directory from the first argument
RAT_DIR_ABS_PATH="$1"

# Validate if the path is provided
if [[ -z "$RAT_DIR_ABS_PATH" ]]; then
    echo "Error: Rat directory path not provided. Usage: bin/uninstall.sh <RAT_DIRECTORY_ABSOLUTE_PATH>"
    exit 1
fi

# Remove the path from ~/.bashrc
echo "Attempting to remove rat-cli path from ~/.bashrc..."
# Escape forward slashes for sed
ESCAPED_PATH=$(echo "$RAT_DIR_ABS_PATH" | sed 's/\//\\\//g')
sed -i "/export PATH=\"$ESCAPED_PATH:\$PATH\"/d" ~/.bashrc

if [ $? -eq 0 ]; then
    echo "Successfully removed rat-cli path from ~/.bashrc."
else
    echo "Failed to remove rat-cli path from ~/.bashrc or path not found. You may need to remove it manually."
fi

# Source .bashrc to apply changes immediately (for the current session)
source ~/.bashrc &> /dev/null # Suppress output

# Delete all files in the rat directory
echo "Deleting all files in the rat directory: $RAT_DIR_ABS_PATH"
read -p "Are you sure you want to delete all files in '$RAT_DIR_ABS_PATH'? This action cannot be undone. (yes/no): " CONFIRMATION
if [[ "$CONFIRMATION" == "yes" ]]; then
    # Ensure we are deleting within the specified directory and not accidentally deleting root
    if [[ "$RAT_DIR_ABS_PATH" == "/" || -z "$RAT_DIR_ABS_PATH" ]]; then
        echo "Error: Cannot delete root directory or empty path. Aborting."
        exit 1
    fi
    rm -rf "$RAT_DIR_ABS_PATH"/*
    rm -rf "$RAT_DIR_ABS_PATH"/.git # Also remove .git if it exists
    echo "All files in '$RAT_DIR_ABS_PATH' have been deleted."
    echo "The rat-cli uninstallation is complete. You may now remove the '$RAT_DIR_ABS_PATH' directory manually if it's empty."
else
    echo "Deletion cancelled. Files in '$RAT_DIR_ABS_PATH' were not deleted."
fi

exit 0
