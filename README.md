## Installation

This guide covers the complete setup of `@rat` including `vscode` and tunneling capabilities.

### 1. Initial Setup and `rat-cli` Accessibility

This step clones the repository, installs the VSCode server and extensions, and makes `rat-cli` accessible from anywhere by adding it to your system's `PATH`.

```bash
# Clone the repository and install VSCode server
git clone https://github.com/ankanbhunia/rat.git
chmod -R +x rat
cd rat
bash ./bin/install_vscode.sh --version 4.22.1 --arch linux-amd64
bash ./bin/download_cloudflared.sh --version 2025.7.0 --arch linux-amd64

# Make rat-cli accessible from anywhere (for Bash users)
echo "export PATH=\"$(pwd):\$PATH\"" >> ~/.bashrc
source ~/.bashrc
```


| Command                                                                                             | Description                                                               |
| :-------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------ |
| 🔑 `rat-cli login`                                                                                   | Logs into your Cloudflare account and copies the necessary certificate.   |
| 💻 `rat-cli vscode [--port <PORT>] [--jumpserver <user@host>] [--domain <domain>]`                 | Starts a VSCode instance, optionally with a specific port, jumpserver, or domain. |
| 🌐 `rat-cli tunnel --port <PORT> [--domain <DOMAIN>] [--subpage_path <PATH>] [--protocol <http/ssh>]` | Tunnels a local port to a public Cloudflare URL.                          |
| 🔗 `rat-cli proxy --jumpserver <user@host>`                                                         | Shares internet via a remote proxy server using a jumpserver.             |
| 🚀 `rat-cli job --domain <DOMAIN> [--node-ids <IDS>] [--name <NAME>] [--nodes <NUM>] [--partition <NAME>] [--time <TIME>] [--gpu-nos <NUM>] [--cpu-nos <NUM>] [--jumpserver <SERVER>]` | Submits a SLURM job to start a VSCode instance on specified nodes. |
| 🔄 `rat-cli sync <LOCAL_PATH> <REMOTE_PATH> [--jumpserver <user@host>] [--direction <upload/download>]` | Synchronizes files/folders between local and remote.                      |
| 🗑️ `rat-cli uninstall`                                                                               | Removes rat-cli from PATH and deletes all associated files.               |
| ⬆️ `rat-cli upgrade`                                                                                | Upgrades rat-cli to the latest version from git and updates VSCode server/extensions. |
| 🔄 `rat-cli install_vscode --version <VERSION> --arch <ARCHITECTURE>`                               | Installs or updates the VSCode server to a specific version and architecture. |
| 🧹 `rat-cli clean`                                                                                  | Stops all running processes started by rat-cli (e.g., VSCode server, tunnels, proxies). |
| 🚀 `rat-cli zj`                                                                                     | Starts a zellij session, downloading it if not found.                     |
| 📦 `rat-cli container [--create <env_name> \| --start <env_name> \| --save <env_name> \| --list \| --delete <env_name>]` | Manages Apptainer container environments (create, start, save, list, delete). |


## `rat-cli container` - Apptainer Container Environment Management

The `rat-cli container` command manages Apptainer container environments, enabling creation, starting, saving, listing, and deletion of isolated computational setups. Apptainer (formerly Singularity) is a container platform ideal for HPC and scientific workloads, integrating seamlessly with existing file systems and schedulers.

### Subcommands:

#### `--create <env_name>`
Creates a new Apptainer container environment.
*   **`<env_name>`**: Unique name for the environment.
*   **Prompts**: Base `.sif` image link, environment directory (sandbox), optional code/data directories to mount.
*   **Process**: Checks Apptainer, creates config, downloads/caches base image, builds writable sandbox.
*   **Example**: `rat-cli container --create my_deep_learning_env`

#### `--start <env_name>`
Starts an existing Apptainer container environment, providing a shell session.
*   **`<env_name>`**: Name of the environment to start.
*   **Process**: Checks Apptainer, reads config, launches Apptainer shell with configured sandbox and mounts.
*   **Example**: `rat-cli container --start my_deep_learning_env`

#### `--save <env_name>`
Saves the current state of a writable sandbox environment into a new Apptainer `.sif` file.
*   **`<env_name>`**: Name of the environment to save.
*   **Prompt**: Output path for the `.sif` file.
*   **Process**: Checks Apptainer, reads config, builds new `.sif` from sandbox.
*   **Example**: `rat-cli container --save my_deep_learning_env`

#### `--list`
Lists all configured `rat-cli` container environments.
*   **Process**: Scans `.containers` directory for config files, displays name, creation date, and sandbox directory.
*   **Example**: `rat-cli container --list`

#### `--delete <env_name>`
Deletes an existing Apptainer container environment, including its sandbox folder and configuration file.
*   **`<env_name>`**: Name of the environment to delete.
*   **Process**: Checks Apptainer, reads config, prompts for confirmation, removes sandbox and config file.
*   **Example**: `rat-cli container --delete my_deep_learning_env`
                     

## `rat-cli job` - SLURM Job Submission for VSCode

The `rat-cli job` command facilitates the submission of SLURM jobs to launch a VSCode instance on specified compute nodes. It automates the process of generating a temporary SLURM batch script with the desired resources and submitting it to the SLURM workload manager.

### Options:

*   **`--node-ids <IDS>`**: Comma-separated list of specific node IDs (e.g., `crannog01,crannog02`). This option is optional.
*   **`--name <NAME>`**: Specifies the SLURM job name. Defaults to `exp`.
*   **`--nodes <NUM>`**: Defines the number of nodes required for the job. This option is optional.
*   **`--partition <NAME>`**: Sets the SLURM partition name. Defaults to `PGR-Standard`.
*   **`--time <TIME>`**: Specifies the SLURM walltime (e.g., `7-00:00:00` for 7 days). Defaults to `7-00:00:00`.
*   **`--gpu-nos <NUM>`**: Specifies the number of GPUs required for the job. This option is optional.
*   **`--cpu-nos <NUM>`**: Specifies the number of CPUs required per task. Defaults to `20`.
*   **`--domain <DOMAIN>`**: **Required**. The full domain for the VSCode tunnel (e.g., `crannog0x.runs.space`).
*   **`--jumpserver <SERVER>`**: The jumpserver address for the VSCode tunnel (e.g., `user@example.com`). This option is optional.
*   **`-h, --help`**: Displays the help message and exits.
*   **`--usage`**: Shows a summary of GPU usage on available nodes and exits.


### Examples:

*   Submit a job to specific nodes with 1 GPU and 20 CPUs, using a domain and jumpserver:
    ```bash
    rat-cli job --node-ids crannog01,crannog02,crannog03 --gpu-nos 1 --cpu-nos 20 --domain crannog0x.runs.space --jumpserver user@example.com
    ```
*   Check GPU usage on available nodes:
    ```bash
    rat-cli job --usage
    ```

## Make any linux-machine ssh-accessible

1 (server-side). Requirements: install openssh-server
```bash
sudo apt install openssh-server
sudo systemctl start ssh
sudo systemctl enable ssh
```
2 (server-side). Start ssh-tunneling -
```bash
rat-cli tunnel --port 22 --domain my-home-network.runs.space --protocol ssh
```
   Add this to ```crontab -e``` --> add ```@reboot sleep 60 && <rat-cli tunnel ... >```

3 (client-side). Requirements: install cloudflared (https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel/).

4 (client-side). Add the following lines to  ```./ssh/config```
```bash
Host my-home-network.runs.space
         ProxyCommand cloudflared access ssh --hostname %h
```
5 (client-side). Connect via ssh:
```bash
ssh ankan@my-home-network.runs.space
```
Alternatively, in one line -
```bash
ssh -o ProxyCommand='cloudflared access ssh --hostname %h' ankan@my-home-network.runs.space
```

## Use any linux-machine as VPN

Save this code in a file i.e., ```home_network.sh``` and run ```bash home_network.sh``` to start the VPN. 

```bash
sshuttle  -e "ssh -q -o ProxyCommand='cloudflared access ssh --hostname %h'"\
 -r ankan@my-home-network.runs.space -x my-home-network.runs.space --no-latency-control 0/0
```


## Share internet via Proxy
This uses the `start_proxy.sh` script to set up an SSH tunnel and a remote proxy server.

```bash
rat-cli proxy --jumpserver s2514643@vico02.inf.ed.ac.uk
```

## Use a Jumpserver to expose a port (in case exposing port is blocked in a machine)
```bash
ssh -R 8000:localhost:8000 s2514643@daisy2.inf.ed.ac.uk rat-cli tunnel --port 8000 --domain viser-host.runs.space
```
## CloudFlare Domain Setup
1. Register for a new domain.
2. Add a new website (the registered domain) to https://dash.cloudflare.com/.
3. Change Nameservers in the domain register site.
4. Create a cert.pem using `rat-cli login`
5. Done!


## Install Zellij (tmux alternative)

```bash
wget https://github.com/zellij-org/zellij/releases/download/v0.42.2/zellij-x86_64-unknown-linux-musl.tar.gz
tar -xvf zellij-x86_64-unknown-linux-musl.tar.gz
mkdir -p ~/.local/bin
mv ./zellij ~/.local/bin/
chmod +x ~/.local/bin/zellij
rm zellij-x86_64-unknown-linux-musl.tar.gz
```

## Build ```container.sif``` from scratch (docker on a sudo machine required)

```
# put Dockerfile in the same path
sudo docker build -t mltoolkit-cuda-12.9:latest  .
sudo apptainer build mltoolkit-cuda-12.9.sif docker-daemon://mltoolkit-cuda-12.9:latest
hf upload ankankbhunia/backups mltoolkit-cuda-12.9.sif apptainer_sifs/mltoolkit-cuda12.9_lite.sif
```

[[Download pre-built .sif files]](https://huggingface.co/ankankbhunia/backups/tree/main/apptainer_sifs)

## Login to Docker using apptainer remote login

```bash
apptainer remote login -u ankan999 oras://docker.io
```

## Download base image from huggingface:

```bash
wget https://huggingface.co/ankankbhunia/backups/resolve/main/apptainer_sifs/mltoolkit-cuda12.1_build_v0.1.sif
```

## Usage of Apptainer .sif container (using --sandbox)

```bash
# typically [SANDBOX_FOLDER] is a folder with high read/write speed/
# [STEP0] create a sandbox
apptainer build --sandbox [SANDBOX_FOLDER] mltoolkit-cuda12.1_build_v0.1.sif

# [USAGE, STEP1] do experiments, install packages, etc.
apptainer shell --nv --writable --fakeroot --bind /lib/x86_64-linux-gnu \
                --bind /disk/nfs/gazinasvolume2/s2514643/:/code \ # [mount folders]
                --bind /raid/s2514643:/data  \
                 [SANDBOX_FOLDER]

# [USAGE, STEP2] start a zellij session (optional)
zellij -s exp

# [STEP3] convert sandbox to .sif (for transfer to different machine or upload to cloud)
apptainer build mltoolkit-cuda12.1_build.sif [SANDBOX_FOLDER]
```

## Usage of Apptainer .sif container (using --overlay)

```bash
# create overlay image of 2GB
dd if=/dev/zero of=overlay.img bs=1M count=2000 && mkfs.ext3 overlay.img
```
```bash
# start the container with the persistent overlay image
apptainer shell --nv --overlay overlay.img --fakeroot --bind /disk/scratch/ mltoolkit-cuda12.1_build.sif
```

```
CONTAINER_PATH=/disk/scratch/s2514643/envs/
apptainer shell --nv --overlay $CONTAINER_PATH/overlay.img --fakeroot --bind /disk/scratch/ $CONTAINER_PATH/mltoolkit-cuda12.1_build.sif
bash ~/rat/vscode --jumpserver s2514643@vico02.inf.ed.ac.uk --port 4080
```


### Use Apptainer for debugging 

```bash
CONTAINER_PATH=/disk/scratch/s2514643/envs/
apptainer run --nv --overlay $CONTAINER_PATH/overlay2.img --fakeroot --bind /disk/scratch/ $CONTAINER_PATH/mltoolkit-cuda12.1_build.sif 
conda activate main
python -m debugpy --listen localhost:5671 -m torch.distributed.launch --nproc_per_node=1 --master_port 48949 train.py
```



### sbatch file job.sh

```bash
#!/bin/bash

# Default values
DEFAULT_GPU_NOS=1
DEFAULT_CPU_NOS=20
DEFAULT_DOMAIN_USERNAME="crannog0x"
DEFAULT_NODE="crannog"

# Function to display help message
show_help() {
    echo "Usage: bash job.sh {node_ids} {gpu_nos} {cpu_nos} {domain_username} {node_name}"
    echo
    echo "Arguments:"
    echo "  node_ids         Comma-separated list of node IDs (e.g., 01,02,03)"
    echo "  gpu_nos          Number of GPUs required (default: $DEFAULT_GPU_NOS)"
    echo "  cpu_nos          Number of CPUs required (default: $DEFAULT_CPU_NOS)"
    echo "  domain_username  Domain username (default: $DEFAULT_DOMAIN_USERNAME)"
    echo "  node_name        Node name prefix (default: $DEFAULT_NODE, options: [damnii, crannog])"
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message and exit"
    echo "  --usage          Show GPU usage summary and exit"
    echo
    echo "Example:"
    echo "  bash job.sh 01,02,03 1 20 crannog0x crannog"
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

# echo -e 'export http_proxy=http://localhost:3128\nexport https_proxy=http://localhost:3128' >> ~/.bashrc && source ~/.bashrc
ssh -L 3128:localhost:3128 -N ${USER}@vico02.inf.ed.ac.uk &

bash rat/vscode --jumpserver ${USER}@vico02.inf.ed.ac.uk --domain ${DOMAIN_USERNAME}.runs.space
EOT

# Print the generated SLURM script for reference
echo "Generated SLURM script:"
cat $TEMP_SCRIPT

# Submit the temporary SLURM script
sbatch $TEMP_SCRIPT

# Clean up the temporary script
rm $TEMP_SCRIPT
```
