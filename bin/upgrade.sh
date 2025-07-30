#!/bin/bash

# Get the absolute path of the rat directory (current working directory)
RAT_DIR_ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

echo "Attempting to upgrade rat-cli from the latest git release..."
echo "Navigating to: $RAT_DIR_ABS_PATH"
cd "$RAT_DIR_ABS_PATH" || { echo "Error: Could not navigate to $RAT_DIR_ABS_PATH. Aborting upgrade."; exit 1; }

# Perform git pull
echo "Pulling latest changes from git repository..."
git pull

if [ $? -eq 0 ]; then
    echo "Git pull successful."

else
    echo "Git pull failed. Please resolve any conflicts or check your network connection."
    exit 1
fi

exit 0
