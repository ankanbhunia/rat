#!/bin/bash

# Script to visualize GPU and node status in a Slurm cluster

# Get the search term from the first argument
search_term="$1"

# Initialize summary counters
total_gpus_sum=0
total_occupied_gpus_sum=0
total_available_gpus_sum=0
total_cpus_sum=0
total_occupied_cpus_sum=0
total_available_cpus_sum=0
down_nodes_count=0
occupied_nodes_count=0
partial_nodes_count=0
available_nodes_count=0
total_nodes_count=0

# Declare associative array for node primary GPU types
declare -A node_primary_gpu_type
# Declare associative arrays for available GPUs and CPUs per node
declare -A node_available_gpus
declare -A node_available_cpus
# Declare associative array for node partitions
declare -A node_partition_map
# Declare associative array for pre-expanded nodelists
declare -A expanded_nodelists


# Fetch all scontrol show node details once
declare -A node_details
echo "Fetching node details..."
current_node=""
while IFS= read -r line; do
    if [[ "$line" =~ NodeName=([^ ]+) ]]; then
        current_node=${BASH_REMATCH[1]}
        node_details[$current_node]="$line"
    elif [[ -n "$current_node" ]]; then
        node_details[$current_node]+=$'\n'"$line"
    fi
done < <(scontrol show node) # Get full output for all nodes

# Pre-expand all unique nodelists from sinfo and squeue
# Collect unique nodelists from sinfo
sinfo_nodelists=$(sinfo -N -o "%10N" | tail -n +2 | sort -u | xargs)
# Collect unique nodelists from squeue (running jobs)
squeue_nodelists=$(squeue -h -t R -o "%R" | sort -u | xargs)

all_unique_nodelists=$(echo "$sinfo_nodelists $squeue_nodelists" | tr ' ' '\n' | sort -u | xargs)

for nodelist_range in $all_unique_nodelists; do
    expanded_nodes=$(scontrol show hostnames "$nodelist_range")
    expanded_nodelists[$nodelist_range]="$expanded_nodes"
done

# Pre-populate node_primary_gpu_type and node_partition_map by iterating through sinfo
while IFS= read -r line; do
    node_sinfo=$(echo "$line" | awk '{print $1}' | xargs) # Node name from sinfo, might be a range
    partition=$(echo "$line" | awk '{print $2}')

    # Use pre-expanded nodelists
    for node in ${expanded_nodelists[$node_sinfo]}; do
        node_info="${node_details[$node]}" # Use pre-fetched info
        if [ -z "$node_info" ]; then
            continue # Skip if no info found for this specific node
        fi

        gres_total_str=$(echo "$node_info" | grep -o 'Gres=[^ ]*' | cut -d= -f2)
        IFS=',' read -ra gres_parts <<< "$gres_total_str"
        for part in "${gres_parts[@]}"; do
            if [[ $part =~ gpu:([^:]+):([0-9]+) ]]; then
                node_primary_gpu_type[$node]=${BASH_REMATCH[1]}
                break
            fi
        done
        node_partition_map[$node]="$partition"
    done
done < <(sinfo -N -o "%10N %P %10T" | grep -v '^UnavailableNodes:' | sort -k1,1 -u)

# Get occupied GPU counts per node, by type, and job time left
declare -A occupied_gpus_by_type
declare -A node_min_time_left # Stores minimum time left for jobs on a node in seconds
declare -A node_job_count # Stores the number of jobs running on each node

# Populate node_job_count
while IFS= read -r line; do
    nodelist=$(echo "$line" | awk '{print $1}')
    # Use pre-expanded nodelists
    for single_node in ${expanded_nodelists[$nodelist]}; do
        node_job_count[$single_node]=$(( ${node_job_count[$single_node]:-0} + 1 ))
    done
done < <(squeue -h -t R -o "%R") # Get nodelist for each running job
# Function to convert D-HH:MM:SS or HH:MM:SS to seconds
time_to_seconds() {
    local time_str="$1"
    local days=0 hours=0 minutes=0 seconds=0

    if [[ "$time_str" =~ ([0-9]+)-([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]; then
        days=${BASH_REMATCH[1]}
        hours=${BASH_REMATCH[2]}
        minutes=${BASH_REMATCH[3]}
        seconds=${BASH_REMATCH[4]}
    elif [[ "$time_str" =~ ([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]; then
        hours=${BASH_REMATCH[1]}
        minutes=${BASH_REMATCH[2]}
        seconds=${BASH_REMATCH[3]}
    fi
    echo $(( 10#$days * 86400 + 10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds ))
}

while read -r nodelist gpus_alloc time_left; do
    # Clean the (IDX:...) part from the gres string
    gpus_alloc_clean=$(echo "$gpus_alloc" | sed 's/(.*)//')
    
    num_gpus=0 # Initialize num_gpus
    job_gpu_type="" # Initialize job_gpu_type

    # Determine if the gres string specifies a GPU type or is a generic 'gpu:N'
    if [[ $gpus_alloc_clean =~ gpu:([^:]+):([0-9]+) ]]; then
        job_gpu_type=${BASH_REMATCH[1]}
        num_gpus=${BASH_REMATCH[2]}
    elif [[ $gpus_alloc_clean =~ gpu:([0-9]+) ]]; then
        num_gpus=${BASH_REMATCH[1]}
        # If no specific type, we will determine it per node later using node_primary_gpu_type
    else
        continue # Skip if neither format matches
    fi

    job_time_left_seconds=$(time_to_seconds "$time_left")

    # Use pre-expanded nodelists
    for single_node in ${expanded_nodelists[$nodelist]}; do
        current_gpu_type="$job_gpu_type"
        if [[ -z "$current_gpu_type" ]]; then
            # If job_gpu_type is empty (i.e., it was gpu:N format), use the primary GPU type for the node
            if [[ -n ${node_primary_gpu_type[$single_node]} ]]; then
                current_gpu_type=${node_primary_gpu_type[$single_node]}
            else
                # Fallback if primary type not found (shouldn't happen if pre-populated correctly)
                current_gpu_type="unknown" 
            fi
        fi
        key="$single_node,$current_gpu_type"
        occupied_gpus_by_type[$key]=$(( ${occupied_gpus_by_type[$key]:-0} + num_gpus ))

        # Update minimum time left for the node
        if [[ -z "${node_min_time_left[$single_node]}" || "$job_time_left_seconds" -lt "${node_min_time_left[$single_node]}" ]]; then
            node_min_time_left[$single_node]="$job_time_left_seconds"
        fi
    done
done < <(squeue -h -t R -o "%R %b %L" | grep "gpu")
echo "------------------------------------------------------------------"
echo "Node Status"
echo "------------------------------------------------------------------"

# Get node status and format it
counter=1
while IFS= read -r line; do
    node_sinfo=$(echo "$line" | awk '{print $1}' | xargs) # Node name from sinfo, might be a range
    # Skip header line from sinfo
    if [[ "$node_sinfo" == "NODELIST" ]]; then continue; fi

    partition=$(echo "$line" | awk '{print $2}')
    state=$(echo "$line" | awk '{print $3}')

    # Expand node ranges from sinfo
    for node in $(scontrol show hostnames "$node_sinfo"); do
        # Apply filter if search_term is provided
        if [[ -n "$search_term" ]]; then
            local_search_term=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
            local_node=$(echo "$node" | tr '[:upper:]' '[:lower:]')
            local_partition=$(echo "$partition" | tr '[:upper:]' '[:lower:]')
            local_node_primary_gpu=$(echo "${node_primary_gpu_type[$node]}" | tr '[:upper:]' '[:lower:]')

            if [[ ! ("$local_node" =~ "$local_search_term" || "$local_partition" =~ "$local_search_term" || "$local_node_primary_gpu" =~ "$local_search_term") ]]; then
                continue # Skip this node if it doesn't match the search term
            fi
        fi

        ((total_nodes_count++))

        node_info="${node_details[$node]}" # Use pre-fetched info
        if [ -z "$node_info" ]; then
            continue # Skip if no info found for this specific node
        fi

    gres_total_str=$(echo "$node_info" | grep -o 'Gres=[^ ]*' | cut -d= -f2)
    cpu_alloc=$(echo "$node_info" | grep -o 'CPUAlloc=[0-9]*' | cut -d= -f2)
    cpu_tot=$(echo "$node_info" | grep -o 'CPUTot=[0-9]*' | cut -d= -f2)

    gpus_display_parts=()
    
    # Initialize flags for overall node GPU status
    has_any_available_gpu=false
    has_any_partial_gpu=false
    has_any_occupied_gpu=false # This means a GPU type is fully occupied

    # Initialize per-node GPU counters
    node_total_gpus=0
    node_occupied_gpus=0
    gpu_type_count=0 # Counter for distinct GPU types on this node

    # Initialize per-node CPU counters
    node_total_cpus=${cpu_tot:-0}
    node_occupied_cpus=${cpu_alloc:-0}
    node_remaining_cpus=$((node_total_cpus - node_occupied_cpus))
    node_available_cpus[$node]=$node_remaining_cpus # Store available CPUs

    total_cpus_sum=$((total_cpus_sum + node_total_cpus))
    total_occupied_cpus_sum=$((total_occupied_cpus_sum + node_occupied_cpus))

    node_current_available_gpus=0 # Initialize for this node
    IFS=',' read -ra gres_parts <<< "$gres_total_str"
    for part in "${gres_parts[@]}"; do
        if [[ $part =~ gpu:([^:]+):([0-9]+) ]]; then
            ((gpu_type_count++)) # Increment GPU type count
            gpu_type_lower=${BASH_REMATCH[1]}
            gpu_type_upper=$(echo "$gpu_type_lower" | tr 'a-z' 'A-Z')
            total_gpus=${BASH_REMATCH[2]}
            key="$node,$gpu_type_lower"
            occupied_count=${occupied_gpus_by_type[$key]:-0}

            total_gpus_sum=$((total_gpus_sum + total_gpus))
            total_occupied_gpus_sum=$((total_occupied_gpus_sum + occupied_count))

            # Sum for per-node summary
            node_total_gpus=$((node_total_gpus + total_gpus))
            node_occupied_gpus=$((node_occupied_gpus + occupied_count))

            current_gpu_color=""
            if (( occupied_count == 0 )); then
                current_gpu_color="32" # Green
                has_any_available_gpu=true
            elif (( occupied_count > 0 && occupied_count < total_gpus )); then
                current_gpu_color="33" # Yellow
                has_any_partial_gpu=true
            else # occupied_count == total_gpus
                current_gpu_color="90" # Grey
                has_any_occupied_gpu=true
            fi
            gpus_display_parts+=("\033[1m$gpu_type_upper\033[22m [$occupied_count/$total_gpus]")
            node_current_available_gpus=$((node_current_available_gpus + (total_gpus - occupied_count)))
        fi
    done
    node_available_gpus[$node]=$node_current_available_gpus # Store available GPUs

    # Determine node state color (based on sinfo state, as before)
    node_color_code="32" # Green default
    if [[ $state == "down"* || $state == "drained" || $state == "inval" ]]; then
        node_color_code="31" # Red
    elif [[ $state == "occupied" || $state == "allocated" ]]; then
        node_color_code="33" # Yellow
    elif [[ $state == "mixed" ]]; then
        node_color_code="33" # Yellow
    fi

    # Determine overall node availability status and color based on GPU counts
    availability_status=""
    availability_color_code=""

    if [[ $state == "down"* || $state == "drained" || $state == "inval" ]]; then
        availability_status="[unavailable]"
        availability_color_code="31" # Red
        ((down_nodes_count++))
    elif (( node_total_gpus == 0 )); then
        # If no GPUs found on the node, consider it available if not down/drained
        availability_status="[available]"
        availability_color_code="32" # Green
        ((available_nodes_count++))
    elif (( node_occupied_gpus == 0 )); then
        availability_status="[available]"
        availability_color_code="32" # Green
        ((available_nodes_count++))
    elif (( node_occupied_gpus > 0 && node_occupied_gpus < node_total_gpus )); then
        availability_status="[partial]"
        availability_color_code="33" # Yellow
        ((partial_nodes_count++))
    elif (( node_occupied_gpus == node_total_gpus )); then
        availability_status="[occupied]"
        availability_color_code="90" # Grey
        ((occupied_nodes_count++))
    else
        # Fallback for unexpected scenarios
        availability_status="[unknown]"
        availability_color_code="37" # White/Default
    fi

    # Build the final display strings
    gpus_display_str=$(printf "%s " "${gpus_display_parts[@]}")
    gpus_display_str=${gpus_display_str% } # Remove trailing space

    # Add per-node total to the display string only if multiple GPU types are present
    if (( node_total_gpus > 0 && gpu_type_count > 1 )); then
        gpus_display_str+=" (Total: $node_occupied_gpus/$node_total_gpus)"
    fi

    # Determine likelihood of availability
    likelihood_status=""
    likelihood_color_code="37" # White color for likelihood status
    if (( node_occupied_gpus > 0 )); then
        if [[ -n "${node_min_time_left[$node]}" ]]; then
            min_time_seconds=${node_min_time_left[$node]}
            min_time_display=$(printf '%d-%02d:%02d:%02d' $((min_time_seconds/86400)) $(( (min_time_seconds%86400)/3600 )) $(( (min_time_seconds%3600)/60 )) $((min_time_seconds%60)))

            if (( min_time_seconds < 3600 )); then # Less than 1 hour
                likelihood_status=" ($min_time_display remaining)"
            elif (( min_time_seconds >= 3600 && min_time_seconds < 21600 )); then # Between 1 and 6 hours
                likelihood_status=" (Medium - $min_time_display remaining)"
            else # Greater than 6 hours
                likelihood_status=" ($min_time_display remaining)"
            fi
        else
            likelihood_status=" (Unknown)"
        fi
    fi

    # Get job count for the current node
    current_node_job_count=${node_job_count[$node]:-0}
    job_count_display=""
    if (( current_node_job_count > 0 )); then
        job_count_display=" ($current_node_job_count jobs running)"
    fi

    # Print the final formatted line
    echo -e "\033[0m($counter) \033[${availability_color_code}m$availability_status \033[1m$node\033[22m, Partition: $partition, State: $state, CPUs: [$node_occupied_cpus/$node_total_cpus], GPUs: $gpus_display_str\033[${likelihood_color_code}m$likelihood_status\033[0m$job_count_display"
    node_map[$counter]="$node" # Store the mapping
    ((counter++))
    done # End of for node in $(scontrol show hostnames "$node_sinfo")
done < <(sinfo -N -o "%10N %P %10T" | grep -v '^UnavailableNodes:' | sort -k1,1 -u)

echo ""

echo "------------------------------------------------------------------"
echo -e "Node State: \033[32mGreen\033[0m=idle, \033[33mYellow\033[0m=mixed/occupied, \033[31mRed\033[0m=down/drained"
echo -e "Availability Status: \033[32mGreen\033[0m=[available], \033[33mYellow\033[0m=[partial], \033[31mRed\033[0m=[unavailable], \033[90mGrey\033[0m=[occupied]"
echo "------------------------------------------------------------------"

total_available_gpus_sum=$((total_gpus_sum - total_occupied_gpus_sum))
total_available_cpus_sum=$((total_cpus_sum - total_occupied_cpus_sum))

echo ""
echo "------------------------------------------------------------------"
echo "Cluster Summary"
echo "------------------------------------------------------------------"
echo -e "\033[0mNodes: $total_nodes_count total. $available_nodes_count available, $partial_nodes_count partial, $occupied_nodes_count occupied, $down_nodes_count down.\033[0m"
echo -e "\033[0mCPUs:  $total_cpus_sum total. $total_available_cpus_sum available, $total_occupied_cpus_sum occupied.\033[0m"
echo -e "\033[0mGPUs:  $total_gpus_sum total. $total_available_gpus_sum available, $total_occupied_gpus_sum occupied.\033[0m"
echo "------------------------------------------------------------------"

# User input for node selection
echo ""
echo "Enter the bullet numbers of the nodes you want to select (e.g., 1,3,5) or press Enter to skip:"
read -r selected_numbers

selected_nodes_list=""
if [[ -n "$selected_numbers" ]]; then
    IFS=',' read -ra numbers_array <<< "$selected_numbers"
    for num in "${numbers_array[@]}"; do
        num=$(echo "$num" | xargs) # Trim whitespace
        if [[ -n "${node_map[$num]}" ]]; then
            if [[ -n "$selected_nodes_list" ]]; then
                selected_nodes_list+=","
            fi
            selected_nodes_list+="${node_map[$num]}"
        else
            echo "Warning: Bullet number '$num' is invalid and will be ignored."
        fi
    done
fi

if [[ -n "$selected_nodes_list" ]]; then
    echo ""
    echo "Selected nodes: $selected_nodes_list"

    min_available_gpus=-1
    min_available_cpus=-1
    selected_partition=""
    # Find the minimum available GPUs and CPUs among selected nodes
    IFS=',' read -ra nodes_array <<< "$selected_nodes_list"
    for node_name in "${nodes_array[@]}"; do
        current_gpus=${node_available_gpus[$node_name]:-0}
        current_cpus=${node_available_cpus[$node_name]:-0}

        if [[ -z "$selected_partition" ]]; then
            selected_partition=${node_partition_map[$node_name]} # Take partition of the first selected node
        fi

        if (( min_available_gpus == -1 || current_gpus < min_available_gpus )); then
            min_available_gpus=$current_gpus
        fi
        if (( min_available_cpus == -1 || current_cpus < min_available_cpus )); then
            min_available_cpus=$current_cpus
        fi
    done

    # Ensure minimums are not negative
    if (( min_available_gpus < 0 )); then min_available_gpus=0; fi
    if (( min_available_cpus < 0 )); then min_available_cpus=0; fi

    echo "────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo "rat-cli job --node-ids \"$selected_nodes_list\" --name \"my_job\" --nodes 1 --partition \"$selected_partition\" --time \"7-00:00:00\" --gpu-nos $min_available_gpus --cpu-nos $min_available_cpus --domain your.domain.here --jumpserver user@example.com"
    echo "────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
else
    echo "No nodes selected."
fi
