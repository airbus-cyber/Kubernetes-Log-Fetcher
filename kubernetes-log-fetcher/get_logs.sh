#!/bin/bash

# This file is part of Kubernetes Log Fetcher.
#
# Copyright (C) 2023 Airbus CyberSecurity SAS
#
# Kubernetes Log Fetcher is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Kubernetes Log Fetcher is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# Kubernetes Log Fetcher. If not, see <https://www.gnu.org/licenses/>.

## Functions
# Function to search for pattern in array
array_contains () { 
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == "$seeking"* ]]; then
            in=0
            break
        fi
    done
    return $in
}

while (true); do

    ## Launch a "kubectl logs" command for each pods, except if the said command is already running on the system.
    # Retrieve all pods in all namespaces.
    pods=$(kubectl get pods -o=jsonpath="{.items[*]['metadata.name', 'metadata.namespace']}" --all-namespaces --field-selector=status.phase=Running)

    # Create an array from the pods variable.
    read -ra pod_array <<< "$pods"
    
    # Retrieve the index of the middle of the array (first half contains pods's name, second half pod's namespace).
    mid_index=$(expr ${#pod_array[@]} / 2)
    
    # Retrieve the list of commands of system running processes containing "kubectl logs".
    mapfile -t ps_array < <( ps -A --no-headers --format cmd | grep "[k]ubectl logs")
    
    # Parse the array.
    for ((i=0; i<$mid_index; i++)); do
        pod="${pod_array[i]}"
        namespace="${pod_array[i+$mid_index]}"
     
        # Check if the kubectl logs command is already running on the system for the current pod/namespace couple.
        # If it is not the case, run the command.
        if ! array_contains ps_array "kubectl logs $pod -n $namespace"; then
            # Check if a log file already exists for that pod/namespace pair
            log_file="/var/log/cloud_cluster/kubelogs/${namespace}_${pod}.log"
            if [ -e $log_file ]; then
                # Retrieve the timestamp of the last entry of the log file (format 2023-04-28T10:58:18.328114804Z)
                last_log=$(tail -n 1 $log_file | awk -F" " '{print $2}')
                timestamp="file lastline"
                # Check if the retrieved date is valid, if not, we take the last modification time of the file
                # This is to ensure the kubectl command do not fail.
                if (! [[  $last_log =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]*Z$ ]] || ! $(date -d "$last_log" &> /dev/null)); then
                    last_log=$(date -r $log_file "+%Y-%m-%dT%H:%m:%S.%sZ")
                    timestamp="file timestamp"
                fi
             
                # Continue log where it was left off
                echo "[INFO] Resuming log collection ($timestamp) for $pod : $namespace" >> /proc/1/fd/1
                kubectl logs "$pod" -n "$namespace" --prefix=true --timestamps=true --all-containers=true --since-time=$last_log --follow >> /var/log/cloud_cluster/kubelogs/${namespace}_${pod}.log &
            else
                # Initial log provisioning
                echo "[INFO] Initializing log collection for $pod : $namespace" >> /proc/1/fd/1
                kubectl logs "$pod" -n "$namespace" --prefix=true --timestamps=true --all-containers=true --follow > /var/log/cloud_cluster/kubelogs/${namespace}_${pod}.log &
            fi
        fi
    done
    
    ## Launch the kubectl get events except if it's already running on the system
    if ! ps -A --no-headers --format cmd | grep "kubectl get events" | grep -v grep > /dev/null ; then
        echo "[INFO] Launching/Resuming kubectl get events command" >> /proc/1/fd/1
        kubectl get events --all-namespaces -o json --watch | jq 'recurse(.[]?) |= if . == null then "null" else . end' -c | jq 'if .items then .items[] else . end' -c > /var/log/cloud_cluster/events.log &
    fi
    
    # Loop every minute
    sleep 60
    echo "############ LOOP ############" >> /proc/1/fd/1
done
