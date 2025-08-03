#!/bin/bash

# Script to visualize GPU and node status in a Slurm cluster

# Initialize summary counters
total_gpus_sum=0
total_occupied_gpus_sum=0
total_available_gpus_sum=0
down_nodes_count=0
occupied_nodes_count=0
partial_nodes_count=0
available_nodes_count=0
total_nodes_count=0

# Declare associative array for node primary GPU types
declare -A node_primary_gpu_type

# Pre-populate node_primary_gpu_type by iterating through sinfo and scontrol show node
while IFS= read -r line; do
    node=$(echo "$line" | awk '{print $1}')
    node_info=$(scontrol show node "$node" 2>/dev/null)
    if [ -z "$node_info" ]; then continue; fi
    gres_total_str=$(echo "$node_info" | grep -o 'Gres=[^ ]*' | cut -d= -f2)
    IFS=',' read -ra gres_parts <<< "$gres_total_str"
    for part in "${gres_parts[@]}"; do
        if [[ $part =~ gpu:([^:]+):([0-9]+) ]]; then
            node_primary_gpu_type[$node]=${BASH_REMATCH[1]}
            break # Take the first GPU type found as primary for this node
        fi
    done
done < <(sinfo -N -o "%10N %12P %10T" | sort -k1,1 -u)

# Get occupied GPU counts per node, by type
declare -A occupied_gpus_by_type
while read -r nodelist gpus_alloc; do
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

    for single_node in $(scontrol show hostnames $nodelist); do
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
    done
done < <(squeue -h -t R -o "%R %b" | grep "gpu")


echo "------------------------------------------------------------------"
echo "Node Status"
echo "------------------------------------------------------------------"

# Get node status and format it
counter=1
# Process substitution is used here to avoid creating a subshell for the while loop
# This ensures that the counter variables are updated in the main shell
while IFS= read -r line; do
    ((total_nodes_count++))
    node=$(echo "$line" | awk '{print $1}')
    partition=$(echo "$line" | awk '{print $2}')
    state=$(echo "$line" | awk '{print $3}')

    node_info=$(scontrol show node "$node" 2>/dev/null)
    if [ -z "$node_info" ]; then continue; fi
    gres_total_str=$(echo "$node_info" | grep -o 'Gres=[^ ]*' | cut -d= -f2)

    gpus_display_parts=()
    
    # Initialize flags for overall node GPU status
    has_any_available_gpu=false
    has_any_partial_gpu=false
    has_any_occupied_gpu=false # This means a GPU type is fully occupied

    # Initialize per-node GPU counters
    node_total_gpus=0
    node_occupied_gpus=0
    gpu_type_count=0 # Counter for distinct GPU types on this node

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
        fi
    done

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

    # Print the final formatted line
    echo -e "\033[0m($counter) \033[${availability_color_code}m$availability_status \033[1m$node\033[22m, Partition: $partition, State: $state, GPUs: $gpus_display_str\033[0m"
    ((counter++))
done < <(sinfo -N -o "%10N %12P %10T" | sort -k1,1 -u)

echo ""
echo "------------------------------------------------------------------"
echo -e "Node State: \033[32mGreen\033[0m=idle, \033[33mYellow\033[0m=mixed/occupied, \033[31mRed\033[0m=down/drained"
echo -e "Availability Status: \033[32mGreen\033[0m=[available], \033[33mYellow\033[0m=[partial], \033[31mRed\033[0m=[unavailable], \033[90mGrey\033[0m=[occupied]"
echo "------------------------------------------------------------------"

total_available_gpus_sum=$((total_gpus_sum - total_occupied_gpus_sum))

echo ""
echo "------------------------------------------------------------------"
echo "Cluster Summary"
echo "------------------------------------------------------------------"
echo -e "\033[0mNodes: $total_nodes_count total. $available_nodes_count available, $partial_nodes_count partial, $occupied_nodes_count occupied, $down_nodes_count down.\033[0m"
echo -e "\033[0mGPUs:  $total_gpus_sum total. $total_available_gpus_sum available, $total_occupied_gpus_sum occupied.\033[0m"
echo "------------------------------------------------------------------"
