#!/bin/bash

# Get the absolute path of the rat directory (current working directory)
RAT_DIR_ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

echo "Attempting to stop all running rat-cli related processes..."

echo "Searching for and stopping processes started by rat-cli..."

# Find PIDs of processes whose command line contains "rat-cli" or its sub-scripts
# This is more robust as it checks the full command line and handles PIDs safely using an array sw
PIDS_TO_KILL_ARRAY=() 
while IFS= read -r pid; do
    PIDS_TO_KILL_ARRAY+=("$pid")
done < <(ps aux | grep -E "rat-cli|zellij|${RAT_DIR_ABS_PATH}/bin/(vscode|tunnel|start_proxy|job|sync|install_vscode|upgrade|login_cloudflare|uninstall|zellij)\.sh" | grep -v "grep" | grep -v "${BASH_SOURCE[0]}" | grep -v "rat-cli clean" | awk '{print $2}' | grep -E '^[0-9]+$')

if [ ${#PIDS_TO_KILL_ARRAY[@]} -eq 0 ]; then
    echo "No rat-cli related processes found."
else
    echo "The following rat-cli related processes are running:"
    # Convert array to comma-separated string for ps -p
    PIDS_COMMA_SEPARATED=$(IFS=,; echo "${PIDS_TO_KILL_ARRAY[*]}")
    ps -p "$PIDS_COMMA_SEPARATED" -o pid,etime,command --no-headers

    read -p "Do you want to terminate these processes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "Attempting to terminate them..."
        # Safely pass PIDs to kill using array expansion (space-separated is fine for kill)
        kill "${PIDS_TO_KILL_ARRAY[@]}"
        echo "Termination attempt complete. Verifying..."
        sleep 2 # Give processes a moment to terminate

        # Verify if processes are still running
        # Redirect stderr to /dev/null in case ps complains about non-existent PIDs
        REMAINING_PIDS=$(ps -p "$PIDS_COMMA_SEPARATED" -o pid= --no-headers 2>/dev/null)
        if [ -z "$REMAINING_PIDS" ]; then
            echo "All identified rat-cli processes have been stopped."
        else
            echo "Some processes are still running (PIDs: $REMAINING_PIDS). Use kill -9 to manually cancel."
        fi
    else
        echo "Aborting termination. No processes were stopped."
    fi
fi

echo "Clean up complete."
