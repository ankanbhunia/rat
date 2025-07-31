#!/bin/bash

# Get the absolute path of the rat directory (current working directory)
RAT_DIR_ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

echo "Attempting to upgrade rat-cli from the latest git release..."
echo "Navigating to: $RAT_DIR_ABS_PATH"
cd "$RAT_DIR_ABS_PATH" || { echo "Error: Could not navigate to $RAT_DIR_ABS_PATH. Aborting upgrade."; exit 1; }

# Perform git pull with autostash to handle local changes gracefully
read -p "This will pull the latest changes and automatically stash/restore your local modifications. Are you sure you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Upgrade cancelled."
    exit 1
fi

echo "Pulling latest changes from git repository..."
echo "Local changes will be automatically stashed and restored."
git pull --autostash

if [ $? -eq 0 ]; then
    echo "Git pull successful."
else
    echo "Git pull failed. Please resolve any conflicts or check your network connection."
    echo "If there was a stash conflict, your changes might be in the latest stash entry. Use 'git stash show' to see them."
    exit 1
fi

exit 0
