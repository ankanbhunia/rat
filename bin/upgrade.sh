#!/bin/bash

# Get the absolute path of the rat directory (current working directory)
RAT_DIR_ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

echo "Attempting to upgrade rat-cli from the latest git release..."
echo "Navigating to: $RAT_DIR_ABS_PATH"
cd "$RAT_DIR_ABS_PATH" || { echo "Error: Could not navigate to $RAT_DIR_ABS_PATH. Aborting upgrade."; exit 1; }

echo "Fetching latest changes from git repository..."
git fetch --all

if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to fetch latest changes. Please check your network connection.\e[0m"
    exit 1
fi

echo "Resetting to the latest version and cleaning untracked files (except those in .gitignore)..."
# Discard all local tracked changes and align with the remote main branch
git reset --hard origin/main

if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to reset local repository. Please resolve issues manually.\e[0m"
    exit 1
fi

# Remove all untracked files and directories that are NOT ignored by .gitignore
git clean -f -d

if [ $? -ne 0 ]; then
    echo -e "\e[31mError: Failed to clean untracked files. Please resolve issues manually.\e[0m"
    exit 1
fi

echo "Repository is now up to date with the latest remote version."


exit 0
