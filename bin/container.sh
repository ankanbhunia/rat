#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
RAT_HOME="$(dirname "$SCRIPT_ABS_DIR")"
CONTAINERS_DIR="$RAT_HOME/.containers"
SIF_CACHE_DIR="$RAT_HOME/.sif_cache"

# Function to check if apptainer is available
check_apptainer() {
    if ! command -v apptainer &> /dev/null; then
        echo "Error: Apptainer is not installed."
        echo "Please install Apptainer manually to use container functionalities."
        exit 1
    fi
}

# Function to check if scp is available
check_scp() {
    if ! command -v scp &> /dev/null; then
        echo "Error: scp is not installed or not in PATH."
        echo "Please ensure OpenSSH client is installed to use remote file functionalities."
        exit 1
    fi
}

# Function to perform image download and sandbox build
perform_build() {
    local env_name=$1
    local config_file=$2
    local base_image_from_config=$3 # This is the base_image from the config file
    local sandbox_folder=$4
    local code_directory=$5
    local data_directory=$6
    local apptainer_prefix_value=$7

    local image_source=""
    local image_type="" # Infer image type within this function

    if [[ "$base_image_from_config" == docker://* ]]; then
        image_type="4" # Docker image
    elif [[ "$base_image_from_config" == http://* || "$base_image_from_config" == https://* ]]; then
        image_type="1" # Public direct SIF link
    elif [[ "$base_image_from_config" =~ ^([^/]+@)?[^/:]+:.+ ]]; then # Matches [user@]host:path
        image_type="3" # Remote SIF file path
    elif [ -f "$base_image_from_config" ]; then
        image_type="2" # Local SIF file path
    else
        echo "Error: Could not infer image type or file does not exist for '$base_image_from_config'. Please provide a valid image source."
        exit 1
    fi

    if [[ "$image_type" == "4" ]]; then # Docker image
        image_source="$base_image_from_config"
    elif [[ "$image_type" == "1" ]]; then # Public direct SIF link
        local sif_filename=$(basename "$base_image_from_config")
        local cached_sif_path="$SIF_CACHE_DIR/$sif_filename"
        image_source="$cached_sif_path" # This is the source for apptainer build
        
        if [ ! -f "$cached_sif_path" ]; then
            echo "Downloading $sif_filename..."
            if command -v pv &> /dev/null; then
                wget -O - "$base_image_from_config" | pv -s "$(wget --spider "$base_image_from_config" 2>&1 | grep 'Length:' | awk '{print $2}')" > "$cached_sif_path"
            else
                wget -O "$cached_sif_path" "$base_image_from_config"
            fi
            
            if [ $? -ne 0 ]; then
                echo "Error: Failed to download .sif file."
                exit 1
            fi
            echo "Download complete. SIF file saved to $cached_sif_path"
        else
            echo "Using cached SIF file: $cached_sif_path"
        fi
    elif [[ "$image_type" == "3" ]]; then # Remote SIF file path
        check_scp # Ensure scp is available
        local remote_sif_full_path="$base_image_from_config" # e.g., user@host:/path/to/image.sif
        
        # Extract just the path part from the remote_sif_full_path
        local remote_file_path_only=$(echo "$remote_sif_full_path" | cut -d':' -f2-)
        
        local sif_filename=$(basename "$remote_file_path_only") # Correctly extract filename from path only
        local cached_sif_path="$SIF_CACHE_DIR/$sif_filename"
        image_source="$cached_sif_path" # This is the source for apptainer build

        if [ ! -f "$cached_sif_path" ]; then
            echo "Checking remote file existence: $remote_sif_full_path..."
            local remote_host_user_part=$(echo "$remote_sif_full_path" | cut -d':' -f1)
            local remote_file_path_only=$(echo "$remote_sif_full_path" | cut -d':' -f2-)
            
            # Check if the remote file exists using ssh and ls
            # This relies on ssh to correctly parse the remote host and use ~/.ssh/config
            if ! ssh "$remote_host_user_part" "ls \"$remote_file_path_only\" &> /dev/null"; then
                echo "Error: Remote SIF file '$remote_file_path_only' not found on '$remote_host_user_part'."
                echo "Please ensure the file exists and you have appropriate SSH access and permissions."
                exit 1
            fi

            echo "Downloading remote SIF file '$remote_sif_full_path' to '$cached_sif_path' using scp..."
            scp "$remote_sif_full_path" "$cached_sif_path"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to download remote .sif file using scp. Please check permissions or network."
                exit 1
            fi
            echo "Download complete. SIF file saved to $cached_sif_path"
        else
            echo "Using cached SIF file from remote source: $cached_sif_path"
        fi
    elif [[ "$image_type" == "2" ]]; then # Local path
        if [ ! -f "$base_image_from_config" ]; then
            echo "Error: Local SIF file '$base_image_from_config' not found."
            exit 1
        fi
        image_source="$base_image_from_config"
        echo "Using local SIF file: $image_source"
    fi

    echo "Building sandbox environment in $sandbox_folder from $image_source..."
    mkdir -p "$sandbox_folder" # Ensure the sandbox directory exists
    apptainer build --sandbox "$sandbox_folder" "$image_source"
    if [ $? -ne 0 ]; then
        echo "Error: Apptainer build failed."
        if [ -d "$sandbox_folder" ]; then
            echo "Cleaning up partially created sandbox directory: $sandbox_folder..."
            rm -rf "$sandbox_folder"
        fi
        exit 1
    fi
    echo "Environment '$env_name' setup complete. You can now run 'rat-cli container --start $env_name' to enter the container."
}

# Function to read config
read_config() {
    local env_name=$1
    local config_file="$CONTAINERS_DIR/$env_name.yaml"

    if [ ! -f "$config_file" ]; then
        echo "Error: Environment '$env_name' not found. Please create it first using 'rat-cli container --create $env_name'."
        exit 1
    fi

    # Read YAML into bash variables (simple key-value parsing)
    # This is a basic parser and might need improvement for complex YAML
    while IFS=':' read -r key value; do
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        case "$key" in
            "base_image") BASE_IMAGE="$value" ;;
            "sandbox_folder") SANDBOX_FOLDER="$value" ;;
            "code_directory") CODE_DIRECTORY="$value" ;;
            "data_directory") DATA_DIRECTORY="$value" ;;
            "apptainer_prefix") APPTAINER_PREFIX="$value" ;;
        esac
    done < "$config_file"
}

# Subcommand: create
container_create() {
    check_apptainer
    check_scp # Ensure scp is available for remote path inference
    local env_name=$1
    if [ -z "$env_name" ]; then
        echo "Usage: rat-cli container --create <env_name>"
        exit 1
    fi

    mkdir -p "$CONTAINERS_DIR"
    mkdir -p "$SIF_CACHE_DIR"

    local config_file="$CONTAINERS_DIR/$env_name.yaml"
    if [ -f "$config_file" ]; then
        echo "Error: Environment '$env_name' already exists. The config file '$config_file' already exists."
        echo "What would you like to do?"
        echo "1) Discard the current config and create a new one"
        echo "2) Rebuild from the current config (skip to download/build)"
        echo "3) Abort"
        read -p "Enter choice (1, 2, or 3): " existing_config_choice

        case "$existing_config_choice" in
            1)
                echo "Discarding existing config and creating a new one."
                rm "$config_file"
                # Continue with the rest of container_create, which will write a new config
                ;;
            2)
                echo "Rebuilding from existing config."
                read_config "$env_name" # This populates global BASE_IMAGE, SANDBOX_FOLDER etc.
                perform_build "$env_name" "$config_file" "$BASE_IMAGE" "$SANDBOX_FOLDER" "$CODE_DIRECTORY" "$DATA_DIRECTORY" "$APPTAINER_PREFIX"
                echo "You can now run 'rat-cli container --start $env_name' to enter the container."
                exit 0
                ;;
            3)
                echo "Aborting."
                exit 1
                ;;
            *)
                echo "Invalid choice. Aborting."
                exit 1
                ;;
        esac
    fi

    local base_image_input_for_new_config="" # This will be the value stored in config

    read -p "Enter base image (e.g., https://.../image.sif, /path/to/image.sif, user@host:/path/to/image.sif, ubuntu:latest): " base_image_input_for_new_config

    local default_sandbox_folder="$CONTAINERS_DIR/$env_name-sandbox"
    read -e -p "Enter environment directory (SANDBOX_FOLDER) (default: $default_sandbox_folder): " sandbox_folder_input
    local sandbox_folder="${sandbox_folder_input:-$default_sandbox_folder}"

    # if [ -d "$sandbox_folder" ]; then
    #     echo "Error: Sandbox directory '$sandbox_folder' already exists. Please choose a different directory or delete the existing one."
    #     exit 1
    # fi

    read -e -p "Enter code directory to mount (optional): " code_directory
    if [ -n "$code_directory" ] && [ ! -d "$code_directory" ]; then
        echo "Error: Code directory '$code_directory' does not exist. Please provide a valid path."
        exit 1
    fi

    read -e -p "Enter data directory to mount (optional): " data_directory
    if [ -n "$data_directory" ] && [ ! -d "$data_directory" ]; then
        echo "Error: Data directory '$data_directory' does not exist. Please provide a valid path."
        exit 1
    fi

    local apptainer_prefix_value="apptainer shell --nv --writable --fakeroot"

    echo "base_image: $base_image_input_for_new_config" > "$config_file"
    echo "sandbox_folder: $sandbox_folder" >> "$config_file"
    [ -n "$code_directory" ] && echo "code_directory: $code_directory" >> "$config_file"
    [ -n "$data_directory" ] && echo "data_directory: $data_directory" >> "$config_file"
    echo "apptainer_prefix: $apptainer_prefix_value" >> "$config_file"

    echo "Config file created: $config_file"

    # Call perform_build for new environment creation
    perform_build "$env_name" "$config_file" "$base_image_input_for_new_config" "$sandbox_folder" "$code_directory" "$data_directory" "$apptainer_prefix_value"
}

# Subcommand: start
container_start() {
    check_apptainer
    local env_name=$1
    if [ -z "$env_name" ]; then
        echo "Usage: rat-cli container --start <env_name>"
        exit 1
    fi

    read_config "$env_name"

    if [ ! -d "$SANDBOX_FOLDER" ]; then
        echo "Error: Sandbox folder '$SANDBOX_FOLDER' does not exist."
        echo "Please create it using 'rat-cli container --create $env_name'."
        exit 1
    fi

    if [ ! -d "$SANDBOX_FOLDER"/code ]; then
        mkdir -p "$SANDBOX_FOLDER"/code
    fi

    if [ ! -d "$SANDBOX_FOLDER"/data ]; then
        mkdir -p "$SANDBOX_FOLDER"/data
    fi

    if [ ! -d "$SANDBOX_FOLDER"/rat ]; then
        mkdir -p "$SANDBOX_FOLDER"/rat
    fi

    local full_start_command="$APPTAINER_PREFIX"
    [ -n "$CODE_DIRECTORY" ] && full_start_command="$full_start_command --bind $CODE_DIRECTORY:/code"
    [ -n "$DATA_DIRECTORY" ] && full_start_command="$full_start_command --bind $DATA_DIRECTORY:/data"
    full_start_command="$full_start_command --bind $RAT_HOME:/rat"
    full_start_command="$full_start_command --env PATH=/rat:$PATH"
    
    full_start_command="$full_start_command $SANDBOX_FOLDER"
    
    
    echo "Starting container environment '$env_name'..."
    echo "$full_start_command"
    eval "$full_start_command"
}

# Subcommand: save
container_save() {
    check_apptainer
    local env_name=$1
    if [ -z "$env_name" ]; then
        echo "Usage: rat-cli container --save <env_name>"
        exit 1
    fi

    read_config "$env_name"

    if [ ! -d "$SANDBOX_FOLDER" ]; then
        echo "Error: Sandbox folder '$SANDBOX_FOLDER' does not exist."
        echo "Please create it using 'rat-cli container --create $env_name'."
        exit 1
    fi

    read -e -p "Enter output path for the .sif file (e.g., /path/to/my_env.sif): " output_sif_path
    if [ -z "$output_sif_path" ]; then
        echo "Error: Output SIF path cannot be empty."
        exit 1
    fi

    echo "Saving container environment '$env_name' to $output_sif_path..."
    apptainer build "$output_sif_path" "$SANDBOX_FOLDER"
    if [ $? -ne 0 ]; then
        echo "Error: Apptainer save failed."
        exit 1
    fi
    echo "Container environment '$env_name' saved successfully to $output_sif_path."
}

# Subcommand: list
container_list() {
    echo "Available container configurations:"
    if [ ! -d "$CONTAINERS_DIR" ] || [ -z "$(ls -A "$CONTAINERS_DIR")" ]; then
        echo "No container configurations found. Create one using 'rat-cli container --create <env_name>'."
        return
    fi

    for config_file in "$CONTAINERS_DIR"/*.yaml; do
        if [ -f "$config_file" ]; then
            local env_name=$(basename "$config_file" .yaml)
            local creation_date=$(stat -c %y "$config_file" | cut -d'.' -f1)
            
            # Read sandbox_folder from config
            local sandbox_folder=""
            local base_image=""
            local apptainer_prefix=""
            while IFS=':' read -r key value; do
                key=$(echo "$key" | xargs)
                value=$(echo "$value" | xargs)
                case "$key" in
                    "sandbox_folder") sandbox_folder="$value" ;;
                    "base_image") base_image="$value" ;;
                    "apptainer_prefix") apptainer_prefix="$value" ;;
                esac
            done < "$config_file"
            
            echo "  - Name: $env_name"
            echo "    Created: $creation_date"
            echo "    Sandbox Directory: $sandbox_folder"
            echo "    Base Image: $base_image"
            echo "    Apptainer Prefix: $apptainer_prefix"
            echo "----------------------------------------"
        fi
    done
}

# Subcommand: delete
container_delete() {
    check_apptainer
    local env_name=$1
    if [ -z "$env_name" ]; then
        echo "Usage: rat-cli container --delete <env_name>"
        exit 1
    fi

    local config_file="$CONTAINERS_DIR/$env_name.yaml"
    if [ ! -f "$config_file" ]; then
        echo "Error: Environment '$env_name' not found."
        exit 1
    fi

    read_config "$env_name"

    echo "WARNING: This will delete the sandbox folder '$SANDBOX_FOLDER' and the configuration file '$config_file'."
    echo "Please ensure you have exited from the container environment '$env_name' before proceeding."
    read -p "Are you sure you want to delete environment '$env_name'? (yes/no): " confirm_delete

    if [[ "$confirm_delete" == "yes" ]]; then
        if [ -d "$SANDBOX_FOLDER" ]; then
            echo "Deleting sandbox folder: $SANDBOX_FOLDER..."
            rm -rf "$SANDBOX_FOLDER"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to delete sandbox folder."
                exit 1
            fi
        else
            echo "Sandbox folder '$SANDBOX_FOLDER' does not exist, skipping deletion."
        fi
        
        echo "Deleting configuration file: $config_file..."
        rm "$config_file"
        echo "Environment '$env_name' deleted successfully."
    else
        echo "Deletion cancelled."
    fi
}

# Main logic for container.sh
case "$1" in
    --create)
        shift
        container_create "$@"
        ;;
    --start)
        shift
        container_start "$@"
        ;;
    --save)
        shift
        container_save "$@"
        ;;
    --list)
        container_list
        ;;
    --delete)
        shift
        container_delete "$@"
        ;;
    *)
        echo "Usage: rat-cli container [--create <env_name> | --start <env_name> | --save <env_name> | --list | --delete <env_name>]"
        exit 1
        ;;
esac
