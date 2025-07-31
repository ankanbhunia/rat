#!/bin/bash

# Get the absolute path of the rat directory (current working directory)
RAT_DIR_ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

echo "Attempting to upgrade rat-cli from the latest git release..."
echo "Navigating to: $RAT_DIR_ABS_PATH"
cd "$RAT_DIR_ABS_PATH" || { echo "Error: Could not navigate to $RAT_DIR_ABS_PATH. Aborting upgrade."; exit 1; }

# Perform git pull
read -p "Local changes detected. Do you want to stash all changes before pulling? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Stashing local changes (including untracked files)..."
    STASH_OUTPUT=$(git stash --include-untracked 2>&1)
    echo "$STASH_OUTPUT"
    if echo "$STASH_OUTPUT" | grep -q "No local changes to save"; then
        STASH_NEEDED=false
    else
        STASH_NEEDED=true
    fi
else
    echo "Aborting upgrade. Please commit or stash your changes manually."
    exit 1
fi

echo "Pulling latest changes from git repository..."
git pull

if [ $? -eq 0 ]; then
    echo "Git pull successful."
    if [ "$STASH_NEEDED" = true ]; then
        echo "Restoring stashed changes..."
        git stash pop
    fi
else
    echo "Git pull failed. Please resolve any conflicts or check your network connection."
    exit 1
fi

exit 0
