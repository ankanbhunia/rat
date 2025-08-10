#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_ABS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
RAT_HOME="$(dirname "$SCRIPT_ABS_DIR")"
CONTAINERS_DIR="$RAT_HOME/.containers"

# Function to strip ANSI escape codes and calculate visible string length
get_visible_length() {
    echo "$1" | sed 's/\x1b\[[0-9;]*[mGKH]//g' | wc -c | xargs
}

# Define colors and reset
COLOR_CYAN=$(tput setaf 6) # Cyan foreground color
COLOR_YELLOW=$(tput setaf 3) # Yellow foreground color
COLOR_RESET=$(tput sgr0)

# Box dimensions
BOX_WIDTH=100 # Total width including borders
BOX_HORIZONTAL_LINE=$(printf '─%.0s' $(seq 1 $((BOX_WIDTH - 2)))) # Unicode horizontal line
BOX_TOP_LEFT="╭"
BOX_TOP_RIGHT="╮"
BOX_BOTTOM_LEFT="╰"
BOX_BOTTOM_RIGHT="╯"
BOX_VERTICAL_LINE="│"

# Fallback to ASCII if unicode is not supported or causes issues
if ! echo -e "\u2500" | grep -q "─"; then
    BOX_HORIZONTAL_LINE=$(printf '-%.0s' $(seq 1 $((BOX_WIDTH - 2))))
    BOX_TOP_LEFT="+"
    BOX_TOP_RIGHT="+"
    BOX_BOTTOM_LEFT="+"
    BOX_BOTTOM_RIGHT="+"
    BOX_VERTICAL_LINE="|"
fi

# Function to print a line within the box (cyan)
print_box_line() {
    local text="$1"
    local visible_text_length=$(get_visible_length "$text")
    local content_width=$((BOX_WIDTH - 2))
    local padding_length=$((content_width - visible_text_length))
    
    if [ "$padding_length" -lt 0 ]; then
        padding_length=0
    fi
    local padding=$(printf ' %.0s' $(seq 1 "$padding_length"))
    printf "${COLOR_CYAN}${BOX_VERTICAL_LINE}%s%s${BOX_VERTICAL_LINE}${COLOR_RESET}\n" "$text" "$padding"
}

# Function to print a line within the box (yellow)
print_box_line_yellow() {
    local text="$1"
    local visible_text_length=$(get_visible_length "$text")
    local content_width=$((BOX_WIDTH - 2))
    local padding_length=$((content_width - visible_text_length))
    
    if [ "$padding_length" -lt 0 ]; then
        padding_length=0
    fi
    local padding=$(printf ' %.0s' $(seq 1 "$padding_length"))
    printf "${COLOR_YELLOW}${BOX_VERTICAL_LINE}%s%s${BOX_VERTICAL_LINE}${COLOR_RESET}\n" "$text" "$padding"
}

# Function to display config file content in a yellow box
display_config_file_content() {
    local config_file="$1"
    local box_horizontal_line_yellow=$(printf '─%.0s' $(seq 1 $((BOX_WIDTH - 2))))
    local box_top_left_yellow="╭"
    local box_top_right_yellow="╮"
    local box_bottom_left_yellow="╰"
    local box_bottom_right_yellow="╯"
    local box_vertical_line_yellow="│"

    if ! echo -e "\u2500" | grep -q "─"; then
        box_horizontal_line_yellow=$(printf '-%.0s' $(seq 1 $((BOX_WIDTH - 2))))
        box_top_left_yellow="+"
        box_top_right_yellow="+"
        box_bottom_left_yellow="+"
        box_bottom_right_yellow="+"
        box_vertical_line_yellow="|"
    fi

    echo ""
    echo "Content of $config_file:"
    echo "${COLOR_YELLOW}${box_top_left_yellow}${box_horizontal_line_yellow}${box_top_right_yellow}${COLOR_RESET}"    
    # Read file content line by line and print within the box
    while IFS= read -r line; do
        print_box_line_yellow "$line"
    done < "$config_file"

    echo "${COLOR_YELLOW}${box_bottom_left_yellow}${box_horizontal_line_yellow}${box_bottom_right_yellow}${COLOR_RESET}"
    echo ""
}


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
    local sif_cache_dir_value=$8 # New parameter for SIF_CACHE_DIR

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
        local cached_sif_path="$sif_cache_dir_value/$sif_filename"
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
        local cached_sif_path="$sif_cache_dir_value/$sif_filename"
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

    local SIF_CACHE_DIR="$RAT_HOME/.sif_cache"

    mkdir -p "$SIF_CACHE_DIR"

    local config_file="$CONTAINERS_DIR/$env_name.yaml"
    if [ -f "$config_file" ]; then
        echo "Error: Environment '$env_name' already exists. The config file '$config_file' already exists."   
        read -p "Would you like to rebuild from the current config? (y/n): " existing_config_choice

        case "$existing_config_choice" in
            [yY])
                echo "Rebuilding from existing config."
                read_config "$env_name" # This populates global BASE_IMAGE, SANDBOX_FOLDER etc.
                perform_build "$env_name" "$config_file" "$BASE_IMAGE" "$SANDBOX_FOLDER" "$CODE_DIRECTORY" "$DATA_DIRECTORY" "$APPTAINER_PREFIX" "$SIF_CACHE_DIR"
                echo "You can now run 'rat-cli container --start $env_name' to enter the container."
                exit 0
                ;;
            [nN])
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

    read -e -p "Enter base directory for sandbox (default: $RAT_HOME/.sandboxes): " BASE_DIRECTORY_INPUT
    local base_directory="${BASE_DIRECTORY_INPUT:-$RAT_HOME/.sandboxes}"

    # Generate a unique directory name for the sandbox within the base directory
    local random_suffix=$(uuidgen)
    local sandbox_folder="$base_directory/$env_name-$random_suffix"

    local code_directory=""
    for i in {1..3}; do
        read -e -p "Enter code directory to mount (default: $RAT_HOME/code): " CODE_DIR_INPUT
        code_directory="${CODE_DIR_INPUT:-$RAT_HOME/code}"
        if [ -z "$code_directory" ] || [ -d "$code_directory" ]; then
            break
        else
            echo "Error: Code directory '$code_directory' does not exist. Please provide a valid path (Attempt $i/3)."
        fi
    done
    if [ ! -d "$code_directory" ]; then
        echo "Warning: Code directory '$code_directory' still does not exist after 3 attempts. Proceeding without mounting a code directory."
        code_directory=""
    fi

    local data_directory=""
    for i in {1..3}; do
        read -e -p "Enter data directory to mount (default: $RAT_HOME/data): " DATA_DIR_INPUT
        data_directory="${DATA_DIR_INPUT:-$RAT_HOME/data}"
        if [ -z "$data_directory" ] || [ -d "$data_directory" ]; then
            break
        else
            echo "Error: Data directory '$data_directory' does not exist. Please provide a valid path (Attempt $i/3)."
        fi
    done
    if [ ! -d "$data_directory" ]; then
        echo "Warning: Data directory '$data_directory' still does not exist after 3 attempts. Proceeding without mounting a data directory."
        data_directory=""
    fi

    read -e -p "Enter Apptainer prefix (default: apptainer shell --nv --writable --fakeroot): " APPTAINER_PREFIX_INPUT
    local apptainer_prefix_value="${APPTAINER_PREFIX_INPUT:-apptainer shell --nv --writable --fakeroot}"

    echo "base_image: $base_image_input_for_new_config" > "$config_file"
    echo "sandbox_folder: $sandbox_folder" >> "$config_file"
    echo "code_directory: $code_directory" >> "$config_file"
    echo "data_directory: $data_directory" >> "$config_file"
    echo "apptainer_prefix: $apptainer_prefix_value" >> "$config_file"

    display_config_file_content "$config_file"

    # Call perform_build for new environment creation
    perform_build "$env_name" "$config_file" "$base_image_input_for_new_config" "$sandbox_folder" "$code_directory" "$data_directory" "$apptainer_prefix_value" "$SIF_CACHE_DIR"
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

    local sandbox_directory_name=$(basename "$SANDBOX_FOLDER")
    local output_sif_path="$SIF_CACHE_DIR/$sandbox_directory_name.sif"

    echo "Saving container environment '$env_name' to $output_sif_path..."
    apptainer build "$output_sif_path" "$SANDBOX_FOLDER"
    if [ $? -ne 0 ]; then
        echo "Error: Apptainer save failed."
        exit 1
    fi
    echo "Container environment '$env_name' saved successfully to $output_sif_path."

    # Update the config file with the new .sif file path as the base_image
    local config_file="$CONTAINERS_DIR/$env_name.yaml"
    if [ -f "$config_file" ]; then
        # Convert output_sif_path to an absolute path before saving to config
        local absolute_output_sif_path=$(realpath "$output_sif_path")
        echo "Updating config file '$config_file' with new base_image: $absolute_output_sif_path"
        sed -i "s|^base_image:.*|base_image: $absolute_output_sif_path|" "$config_file"
        if [ $? -ne 0 ]; then
            echo "Warning: Failed to update base_image in config file."
        fi
        display_config_file_content "$config_file"
    else
        echo "Warning: Config file '$config_file' not found, skipping base_image update."
    fi
}

# Subcommand: copy
container_copy() {
    local source_env_name=$1
    local new_env_name=$2

    if [ -z "$source_env_name" ] || [ -z "$new_env_name" ]; then
        echo "Usage: rat-cli container --copy <source_env_name> <new_env_name>"
        exit 1
    fi

    local source_config_file="$CONTAINERS_DIR/$source_env_name.yaml"
    local new_config_file="$CONTAINERS_DIR/$new_env_name.yaml"

    if [ ! -f "$source_config_file" ]; then
        echo "Error: Source environment '$source_env_name' not found. Config file '$source_config_file' does not exist."
        exit 1
    fi

    if [ -f "$new_config_file" ]; then
        echo "Error: Target environment '$new_env_name' already exists. Config file '$new_config_file' already exists."
        exit 1
    fi

    # Read source config to get its sandbox folder
    local SOURCE_SANDBOX_FOLDER=""
    local BASE_IMAGE_FROM_SOURCE=""
    local CODE_DIRECTORY_FROM_SOURCE=""
    local DATA_DIRECTORY_FROM_SOURCE=""
    local APPTAINER_PREFIX_FROM_SOURCE=""

    while IFS=':' read -r key value; do
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        case "$key" in
            "base_image") BASE_IMAGE_FROM_SOURCE="$value" ;;
            "sandbox_folder") SOURCE_SANDBOX_FOLDER="$value" ;;
            "code_directory") CODE_DIRECTORY_FROM_SOURCE="$value" ;;
            "data_directory") DATA_DIRECTORY_FROM_SOURCE="$value" ;;
            "apptainer_prefix") APPTAINER_PREFIX_FROM_SOURCE="$value" ;;
        esac
    done < "$source_config_file"

    if [ -z "$SOURCE_SANDBOX_FOLDER" ] || [ ! -d "$SOURCE_SANDBOX_FOLDER" ]; then
        echo "Error: Source sandbox folder '$SOURCE_SANDBOX_FOLDER' not found or not specified in config."
        exit 1
    fi

    # Generate a new unique sandbox folder for the new environment, using the source's base directory
    local source_base_directory=$(dirname "$SOURCE_SANDBOX_FOLDER")
    local random_suffix=$(uuidgen)
    local new_sandbox_folder="$source_base_directory/$new_env_name-$random_suffix"

    if [ -d "$new_sandbox_folder" ]; then
        echo "Error: Generated new sandbox directory '$new_sandbox_folder' already exists. Please try again."
        exit 1
    fi

    echo "Creating new config file: $new_config_file"
    cp "$source_config_file" "$new_config_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy source config file to new config file."
        exit 1
    fi

    echo "Updating sandbox_folder in new config file to: $new_sandbox_folder"
    sed -i "s|^sandbox_folder:.*|sandbox_folder: $new_sandbox_folder|" "$new_config_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update sandbox_folder in new config file."
        exit 1
    fi

    display_config_file_content "$new_config_file"

    echo "Copying sandbox directory from '$SOURCE_SANDBOX_FOLDER' to '$new_sandbox_folder'..."
    local start_time=$(date +%s)
    rsync -aH "$SOURCE_SANDBOX_FOLDER" "$new_sandbox_folder"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "Sandbox directory copy completed in ${duration} seconds."
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy sandbox directory."
        rm -f "$new_config_file" # Clean up created config file
        rm -rf "$new_sandbox_folder" # Clean up partially copied sandbox
        exit 1
    fi

    echo "Environment '$source_env_name' successfully copied to '$new_env_name'."
    echo "New sandbox directory: $new_sandbox_folder"
    echo "New config file: $new_config_file"
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
            echo "    Config Path: $config_file"
            echo "----------------------------------------"
        fi
    done
}

# Subcommand: edit
container_edit() {
    local env_name=$1
    if [ -z "$env_name" ]; then
        echo "Usage: rat-cli container --edit <env_name>"
        exit 1
    fi

    local config_file="$CONTAINERS_DIR/$env_name.yaml"
    if [ ! -f "$config_file" ]; then
        echo "Error: Environment '$env_name' not found. Config file '$config_file' does not exist."
        exit 1
    fi

    echo "Opening config file '$config_file' for editing..."
    if command -v code &> /dev/null; then
        nano "$config_file"
    else
        # Fallback to vi if code is not available
        vi "$config_file"
    fi

    if [ $? -ne 0 ]; then
        echo "Error: Failed to open or edit config file."
        exit 1
    fi

    echo "Config file '$config_file' updated."
    display_config_file_content "$config_file"
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
    --copy)
        shift
        container_copy "$@"
        ;;
    --edit)
        shift
        container_edit "$@"
        ;;
    *)
        echo "Usage: rat-cli container [--create <env_name> | --start <env_name> | --save <env_name> | --list | --delete <env_name> | --copy <source_env_name> <new_env_name> | --edit <env_name>]"
        exit 1
        ;;
esac
