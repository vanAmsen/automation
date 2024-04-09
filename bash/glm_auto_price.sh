#!/bin/bash

# curl -o glm_auto_price.sh https://raw.githubusercontent.com/vanAmsen/automation/main/bash/glm_auto_price.sh
# chmod +x glm_auto_price.sh

# Function to get task count
get_task_count() {
    local count=$(golemsp status | grep -oP 'last 1h (processed|in progress)\s+\K\d+' | paste -sd+ | bc)
    echo "$count"
}

# Function to get current CPU price
get_current_cpu_price() {
    # Extract the CPU price for "vm" preset
    local price=$(golemsp settings show | awk '/Pricing for preset "vm":/{flag=1;next}/Pricing for preset/{flag=0}flag' | grep -oP '^\s+\K\d+\.\d+(?= GLM per cpu hour)')
    echo "$price"
}

# Function to update price
update_price() {
    local new_price=$1
    echo "Updating price to: $new_price"
    golemsp settings set --env-per-hour $new_price --cpu-per-hour $new_price
}

# Main logic
task_count=$(get_task_count)
echo "Task count: $task_count"

current_price=$(get_current_cpu_price)
echo "Current price: $current_price"

# Check if current price is valid
if ! [[ $current_price =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid current price format."
    exit 1
fi

# If no tasks processed or in progress in the last hour
if [ "$task_count" -eq 0 ]; then
    # Decrease price by 5%
    new_price=$(echo "scale=18; $current_price * 0.95" | bc -l)
    update_price $new_price
    echo "Price decreased to $new_price"
else
    # Increase price by 5%
    new_price=$(echo "scale=18; $current_price * 1.05" | bc -l)
    update_price $new_price
    echo "Price increased to $new_price"
fi
