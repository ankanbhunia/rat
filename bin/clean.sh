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
done < <(ps aux | grep -E "rat-cli" | grep -v "grep" | grep -v "${BASH_SOURCE[0]}" | grep -v "rat-cli clean" | awk '{print $2}' | grep -E '^[0-9]+$')

# Function to kill a process and its children recursively
killtree() {
  local _pid=$1
  echo "Killing PID: $_pid" # Print the PID being killed
  for _child in $(pgrep -P $_pid); do
    killtree $_child
  done
  kill -9 $_pid 2>/dev/null # Use 2>/dev/null to suppress "No such process" errors
}

if [ ${#PIDS_TO_KILL_ARRAY[@]} -eq 0 ]; then
    echo "No rat-cli related processes found."
else
    echo "The following rat-cli related processes are running:"
    # Store PID and command for interactive selection
    declare -A PROCESS_MAP
    INDEX=1
    for PID in "${PIDS_TO_KILL_ARRAY[@]}"; do
        CMD=$(ps -p "$PID" -o command= --no-headers 2>/dev/null)
        if [ -n "$CMD" ]; then
            PROCESS_MAP["$INDEX"]="$PID"
            echo "  $INDEX) PID: $PID - CMD: $CMD"
            INDEX=$((INDEX+1))
        fi
    done

    if [ ${#PROCESS_MAP[@]} -eq 0 ]; then
        echo "No active rat-cli related processes found after detailed check."
    else
        read -p "Enter numbers of processes to terminate (e.g., '1 3 5'), 'a' for all, or 'n' to abort: " -r SELECTION
        echo

        if [[ "$SELECTION" =~ ^[Nn]$ ]]; then
            echo "Aborting termination. No processes were stopped."
        elif [[ "$SELECTION" =~ ^[Aa]$ ]]; then
            echo "Attempting to terminate all identified processes and their children..."
            for PID in "${PIDS_TO_KILL_ARRAY[@]}"; do
                killtree "$PID"
            done
            echo "Termination attempt complete. Verifying..."
            sleep 2 # Give processes a moment to terminate

            # Verify if processes are still running
            PIDS_COMMA_SEPARATED=$(IFS=,; echo "${PIDS_TO_KILL_ARRAY[*]}")
            REMAINING_PIDS=$(ps -p "$PIDS_COMMA_SEPARATED" -o pid= --no-headers 2>/dev/null)
            if [ -z "$REMAINING_PIDS" ]; then
                echo "All identified rat-cli processes have been stopped."
            else
                echo "Some processes are still running (PIDs: $REMAINING_PIDS). Use kill -9 to manually cancel."
            fi
        else
            PIDS_TO_TERMINATE=()
            for NUM in $SELECTION; do
                if [[ -v PROCESS_MAP["$NUM"] ]]; then
                    PIDS_TO_TERMINATE+=("${PROCESS_MAP["$NUM"]}")
                else
                    echo "Warning: Invalid selection '$NUM' ignored."
                fi
            done

            if [ ${#PIDS_TO_TERMINATE[@]} -eq 0 ]; then
                echo "No valid processes selected for termination. Aborting."
            else
                echo "Attempting to terminate selected processes and their children: ${PIDS_TO_TERMINATE[*]}..."
                for PID in "${PIDS_TO_TERMINATE[@]}"; do
                    killtree "$PID"
                done
                echo "Termination attempt complete. Verifying..."
                sleep 2 # Give processes a moment to terminate

                # Verify if selected processes are still running
                PIDS_COMMA_SEPARATED=$(IFS=,; echo "${PIDS_TO_TERMINATE[*]}")
                REMAINING_PIDS=$(ps -p "$PIDS_COMMA_SEPARATED" -o pid= --no-headers 2>/dev/null)
                if [ -z "$REMAINING_PIDS" ]; then
                    echo "All selected processes have been stopped."
                else
                    echo "Some selected processes are still running (PIDs: $REMAINING_PIDS). Use kill -9 to manually cancel."
                fi
            fi
        fi
    fi
fi

echo "Clean up complete."
