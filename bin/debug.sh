#!/bin/bash

# Usage: ./debug.sh [--jumpserver <user@host>] [--port <port>] <python_cmd_and_args...>
# Example:
# ./debug.sh --jumpserver user@login-node-name --port 48949 -m torch.distributed.launch --nproc_per_node=1 --master_port 48949 test.py

JUMPSERVER=""
PORT=""
PYTHON_CMD_ARGS=()

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --jumpserver)
            JUMPSERVER="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        *)
            PYTHON_CMD_ARGS+=("$1")
            shift
            ;;
    esac
done

if [ -z "$PORT" ]; then
    # Find a free random port between 2000 and 65000 if not provided
    PORT=$(shuf -i 2000-65000 -n 1)
    while nc -z localhost $PORT 2>/dev/null; do
        PORT=$(shuf -i 2000-65000 -n 1)
    done
fi

echo "[INFO] Using debugpy port: $PORT"

# Start debugpy, prefixing output for clarity
python -m debugpy --listen localhost:$PORT --wait-for-client "${PYTHON_CMD_ARGS[@]}" 2>&1 | sed 's/^/[PYTHON] /' &
DEBUGPY_PID=$!

echo "[INFO] debugpy is listening on port $PORT"

if [ -n "$JUMPSERVER" ]; then
    # Start SSH reverse tunnel in foreground (for password prompt and logs)
    ssh -NR $PORT:localhost:$PORT "$JUMPSERVER"
    # When tunnel closes, kill debugpy
    kill $DEBUGPY_PID 2>/dev/null
    echo "[INFO] debugpy exited, tunnel closed."
else
    # Wait for debugpy process to exit naturally
    wait $DEBUGPY_PID
    echo "[INFO] debugpy exited."
fi
