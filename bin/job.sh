#!/bin/bash

# Default values
DEFAULT_GPU_NOS=1
DEFAULT_CPU_NOS=20
DEFAULT_DOMAIN_USERNAME="crannog0x"
DEFAULT_NODE="crannog"

# Function to display help message
show_help() {
    echo "Usage: rat-cli job <NODE_IDS> [GPU_NOS] [CPU_NOS] [DOMAIN_USERNAME] [NODE_NAME] [OPTIONS]"
    echo "Description: Submits a SLURM job to start a VSCode instance on specified nodes."
    echo "             This command generates a temporary SLURM batch script and submits it."
    echo ""
    echo "Arguments:"
    echo "  NODE_IDS         Comma-separated list of node IDs (e.g., 01,02,03). (Required)"
    echo "  GPU_NOS          Number of GPUs required for the job. (Default: $DEFAULT_GPU_NOS)"
    echo "  CPU_NOS          Number of CPUs required for the job. (Default: $DEFAULT_CPU_NOS)"
    echo "  DOMAIN_USERNAME  Domain username for the VSCode tunnel. (Default: $DEFAULT_DOMAIN_USERNAME)"
    echo "  NODE_NAME        Node name prefix (e.g., crannog, damnii). (Default: $DEFAULT_NODE)"
    echo ""
    echo "Options:"
    echo "  -h, --help       Display this help message and exit."
    echo "  --usage          Show a summary of GPU usage on available nodes and exit."
    echo ""
    echo "Requirements:"
    echo "  - SLURM workload manager must be installed and configured on the system."
    echo "  - 'rat-cli vscode' must be accessible on the remote node."
    echo "  - SSH client must be installed for proxy tunneling (if enabled in the SLURM script)."
    echo ""
    echo "Workflow:"
    echo "1. Parses command-line arguments for node, GPU, CPU, domain, and node name."
    echo "2. Constructs a SLURM nodelist based on the provided node IDs and name."
    echo "3. Generates a temporary SLURM batch script with the specified resources."
    echo "4. The generated script includes a call to 'rat-cli vscode' to launch VSCode."
    echo "5. Submits the temporary SLURM script using 'sbatch'."
    echo "6. Cleans up the temporary SLURM script."
    echo ""
    echo "Examples:"
    echo "  rat-cli job 01,02,03 1 20 crannog0x crannog"
    echo "  rat-cli job 05 --gpu_nos 2 --cpu_nos 30"
    echo "  rat-cli job --usage"
}

# Function to summarize GPU usage on each node
summarize_gpu_usage() {
    squeue | grep -E 'crannog|damnii' | awk '{print $NF}' | sort | uniq -c | awk '{print "Node: " $2 ", GPUs: " $1}'
}

# Check if help or usage is requested
if [[ "$1" == "-h" || "$1" == "--help" || $# -eq 0 ]]; then
    show_help
    exit 0
elif [[ "$1" == "--usage" ]]; then
    summarize_gpu_usage
    exit 0
fi

# Read command-line arguments
NODE_IDS=$1
GPU_NOS=${2:-$DEFAULT_GPU_NOS}
CPU_NOS=${3:-$DEFAULT_CPU_NOS}
DOMAIN_USERNAME=${4:-$DEFAULT_DOMAIN_USERNAME}
NODE_NAME=${5:-$DEFAULT_NODE}

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the absolute path of the parent directory (rat_copy)
PARENT_ABS_DIR="$(dirname "$SCRIPT_ABS_DIR")"

# Create a temporary SLURM script
TEMP_SCRIPT=$(mktemp)

# Construct the nodelist
NODE_LIST=$(echo $NODE_IDS | sed "s/,/,${NODE_NAME}/g")
NODE_LIST="${NODE_NAME}${NODE_LIST}"

cat <<EOT > $TEMP_SCRIPT
#!/bin/bash
#SBATCH --job-name=lnnexp           # Job name
#SBATCH --nodes=1
#SBATCH --nodelist=${NODE_LIST}     # Node list
#SBATCH --gres=gpu:${GPU_NOS}       # Number of GPUs required
#SBATCH --cpus-per-task=${CPU_NOS}  # Number of CPUs required
#SBATCH --partition=PGR-Standard
#SBATCH --time=7-00:00:00           # Walltime

# Ensure rat-cli is in PATH for the SLURM job, or use absolute path
# If rat-cli is not in the default PATH for SLURM jobs, uncomment and adjust the following line:
# export PATH="$PARENT_ABS_DIR:$PATH"

# Call rat-cli vscode with the appropriate arguments
"$PARENT_ABS_DIR"/rat-cli vscode --domain ${DOMAIN_USERNAME}.runs.space --jumpserver ${USER}@vico02.inf.ed.ac.uk
EOT

# Print the generated SLURM script for reference
echo "Generated SLURM script:"
cat $TEMP_SCRIPT

# Submit the temporary SLURM script
sbatch $TEMP_SCRIPT

# Clean up the temporary script
rm $TEMP_SCRIPT
