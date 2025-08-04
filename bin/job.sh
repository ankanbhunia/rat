#!/bin/bash

# Default values
DEFAULT_JOB_NAME="exp"
DEFAULT_PARTITION="PGR-Standard"
DEFAULT_TIME="7-00:00:00"
DEFAULT_CPU_NOS=20

# Function to display help message
show_help() {
    echo "Usage: rat-cli job [OPTIONS]"
    echo "Description: Submits a SLURM job to start a VSCode instance on specified nodes."
    echo "             This command generates a temporary SLURM batch script and submits it."
    echo ""
    echo "Options:"
    echo "  --node-ids <IDS>       Comma-separated list of node IDs (e.g., crannog01,crannog02). (Optional)"
    echo "  --name <NAME>          SLURM job name. (Default: $DEFAULT_JOB_NAME)"
    echo "  --nodes <NUM>          Number of nodes for the job. (Optional)"
    echo "  --partition <NAME>     SLURM partition name. (Default: $DEFAULT_PARTITION)"
    echo "  --time <TIME>          SLURM walltime (e.g., 7-00:00:00). (Default: $DEFAULT_TIME)"
    echo "  --gpu-nos <NUM>        Number of GPUs required for the job. (Optional)"
    echo "  --cpu-nos <NUM>        Number of CPUs required for the job. (Default: $DEFAULT_CPU_NOS)"
    echo "  --domain <DOMAIN>      Full domain for the VSCode tunnel. (Required)"
    echo "  --jumpserver <SERVER>  Jumpserver address for the VSCode tunnel. (Optional)"
    echo "  -h, --help             Display this help message and exit."
    echo "  --usage                Show a summary of GPU usage on available nodes and exit."
    echo ""
    echo "Requirements:"
    echo "  - SLURM workload manager must be installed and configured on the system."
    echo "  - 'rat-cli vscode' must be accessible on the remote node."
    echo "  - SSH client must be installed for proxy tunneling (if enabled in the SLURM script)."
    echo ""
    echo "Workflow:"
    echo "1. Parses command-line arguments for job parameters."
    echo "2. Constructs a SLURM nodelist based on the provided node IDs."
    echo "3. Generates a temporary SLURM batch script with the specified resources."
    echo "4. The generated script includes a call to 'rat-cli vscode' to launch VSCode."
    echo "5. Submits the temporary SLURM script using 'sbatch'."
    echo "6. Cleans up the temporary SLURM script."
    echo ""
    echo "Examples:"
    echo "  rat-cli job --node-ids crannog01,crannog02,crannog03 --gpu-nos 1 --cpu-nos 20 --domain crannog0x.runs.space --jumpserver user@example.com"
    echo "  rat-cli job --node-ids crannog05 --gpu-nos 2 --cpu-nos 30 --jumpserver user@example.com"
    echo "  rat-cli job --usage"
}


# Parse command-line arguments
TEMP=$(getopt -o h --long node-ids:,name:,nodes:,partition:,time:,gpu-nos:,cpu-nos:,domain:,jumpserver:,help -n 'rat-cli job' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around '$TEMP': they are essential!
eval set -- "$TEMP"

NODE_IDS=""
JOB_NAME="$DEFAULT_JOB_NAME"
NODES="" # Make NODES optional
PARTITION="$DEFAULT_PARTITION"
TIME="$DEFAULT_TIME"
GPU_NOS="" # Make GPU_NOS optional
CPU_NOS="$DEFAULT_CPU_NOS"
DOMAIN="" # Initialize DOMAIN as empty
JUMPSERVER="" # Initialize JUMPSERVER as empty

while true ; do
    case "$1" in
        --node-ids) NODE_IDS="$2" ; shift 2 ;;
        --name) JOB_NAME="$2" ; shift 2 ;;
        --nodes) NODES="$2" ; shift 2 ;;
        --partition) PARTITION="$2" ; shift 2 ;;
        --time) TIME="$2" ; shift 2 ;;
        --gpu-nos) GPU_NOS="$2" ; shift 2 ;;
        --cpu-nos) CPU_NOS="$2" ; shift 2 ;;
        --domain) DOMAIN="$2" ; shift 2 ;;
        --jumpserver) JUMPSERVER="$2" ; shift 2 ;;
        -h|--help) show_help ; exit 0 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ; fi
    esac
done

# Check if DOMAIN is provided
if [ -z "$DOMAIN" ]; then
    echo "Error: --domain is a required argument."
    show_help
    exit 1
fi

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat_copy)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

# Create a temporary SLURM script
TEMP_SCRIPT=$(mktemp)

# Construct SLURM options conditionally
NODE_LIST_SLURM=""
if [ -n "$NODE_IDS" ]; then
    NODE_LIST_SLURM="#SBATCH --nodelist=${NODE_IDS}"
fi

NODES_SLURM=""
if [ -n "$NODES" ]; then
    NODES_SLURM="#SBATCH --nodes=${NODES}"
fi

GPU_NOS_SLURM=""
if [ -n "$GPU_NOS" ]; then
    GPU_NOS_SLURM="#SBATCH --gres=gpu:${GPU_NOS}"
fi

# Construct the command for rat-cli vscode
VSCODE_COMMAND="$PARENT_ABS_DIR/rat-cli vscode --domain \"${DOMAIN}\""
if [ -n "$JUMPSERVER" ]; then
    VSCODE_COMMAND="${VSCODE_COMMAND} --jumpserver \"${JUMPSERVER}\""
fi

cat <<EOT > "$TEMP_SCRIPT"
#!/bin/bash
#SBATCH --chdir=$HOME
#SBATCH --job-name=${JOB_NAME}           # Job name
${NODES_SLURM}
${NODE_LIST_SLURM}     # Node list (optional)
${GPU_NOS_SLURM}       # Number of GPUs required (optional)
#SBATCH --cpus-per-task=${CPU_NOS}  # Number of CPUs required
#SBATCH --partition=${PARTITION}
#SBATCH --time=${TIME}           # Walltime


# Ensure rat-cli is in PATH for the SLURM job, or use absolute path
# If rat-cli is not in the default PATH for SLURM jobs, uncomment and adjust the following line:
# export PATH="$PARENT_ABS_DIR:$PATH"

# Call rat-cli vscode with the appropriate arguments
if [ -n "$JUMPSERVER" ]; then
    "$PARENT_ABS_DIR"/rat-cli vscode --domain "${DOMAIN}" --jumpserver "${JUMPSERVER}"
else
    "$PARENT_ABS_DIR"/rat-cli vscode --domain "${DOMAIN}"
fi
EOT

# Print the generated SLURM script for reference
echo "Generated SLURM script:"
cat $TEMP_SCRIPT

# Submit the temporary SLURM script
sbatch $TEMP_SCRIPT

# Clean up the temporary script
rm $TEMP_SCRIPT
