#!/bin/bash

# curl -o glm_auto_price.sh https://raw.githubusercontent.com/vanAmsen/automation/main/bash/glm_auto_price.sh
# chmod +x glm_auto_price.sh
# 0 * * * * /home/ubuntu/glm_auto_price.sh

PATH=$PATH:/root/.local/bin
export PATH

# Function to get task count
get_task_count() {
    local count=$(golemsp status | grep -oP 'last 1h (processed|in progress)\s+\K\d+' | paste -sd+ | bc)
    echo "$count"
}

# Function to get current CPU price
get_current_cpu_price() {
    local price=$(golemsp settings show | awk '/Pricing for preset "vm":/{flag=1;next}/Pricing for preset/{flag=0}flag' | grep -oP '^\s+\K\d+\.\d+(?= GLM per cpu hour)')
    echo "$price"
}

# Function to update price
update_price() {
    local new_price=$1
    echo "Updating price to: $new_price"
    golemsp settings set --env-per-hour $new_price --cpu-per-hour $new_price
}

restart_golemsp() {
    echo "Attempting to restart golemsp..."

    # Get the current hour and force it to be interpreted in base 10
    local current_hour=$(date +"%H")
    current_hour=$((10#$current_hour))

    # Check if the current hour is divisible by 4
    if (( current_hour % 4 != 0 )); then
        echo "Current hour ($current_hour) is not divisible by 4. Skipping golemsp restart."
        return
    fi

    # Find the last detached 'provider' screen session
    local session_id=$(screen -list | grep 'Detached' | grep 'provider' | awk '{print $1}' | head -n 1)

    if [ -z "$session_id" ]; then
        echo "No detached provider screen session found. Attempting to start golemsp in a new session."
        screen -dmS provider bash -c 'golemsp run; exec sh'
        return
    fi

    # Restart logic for when a detached session is found
    echo "Detached provider session found: $session_id. Sending Ctrl+C to stop golemsp."
    screen -S "$session_id" -X stuff $'\\003' # Send Ctrl+C
    sleep 10 # Wait for 10 seconds

    echo "Starting golemsp in the same screen session..."
    screen -S "$session_id" -X stuff $'golemsp run\n'
    sleep 5 # Wait for 5 seconds to ensure it starts
}

# Main logic
task_count=$(get_task_count)
echo "$(date +"%Y-%m-%d %H:%M:%S") - Task count: $task_count"

current_price=$(get_current_cpu_price)
echo "Current price: $current_price"

# Check if current price is valid
if ! [[ $current_price =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid current price format."
    exit 1
fi

# If no tasks processed or in progress in the last hour
if [ "$task_count" -eq 0 ]; then
    new_price=$(echo "scale=18; $current_price * 0.98" | bc -l)
    update_price $new_price
    echo "Price decreased to $new_price"
    
    # Restart golemsp
    restart_golemsp
    echo "Restarted golemsp"
else
    # Increase price by 4%
    new_price=$(echo "scale=18; $current_price * 1.03" | bc -l)
    update_price $new_price
    echo "Price increased to $new_price"
fi
