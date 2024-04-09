#!/bin/bash

# Check if the IP file is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <IP_FILE>"
    exit 1
fi

IP_FILE=$1

# Check if the IP file exists
if [ ! -f "$IP_FILE" ]; then
    echo "IP file not found: $IP_FILE"
    exit 1
fi

# Full path of golemsp obtained from the 'which' command
GOLEMSP_PATH="/root/.local/bin/golemsp"

# Read IPs into an array
mapfile -t IPS < "$IP_FILE"

# Loop through each IP in the array and execute the command
for IP_ADDRESS in "${IPS[@]}"; do
    echo "Running commands for $IP_ADDRESS"
    ssh -tt ubuntu@$IP_ADDRESS "sudo $GOLEMSP_PATH settings set --starting-fee 0 --env-per-hour 0.003 --cpu-per-hour 0.003"
done
