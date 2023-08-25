#!/bin/bash

# Get the value of the environment variable
PORT_VALUE=$RUNPOD_TCP_PORT_70000

# Write the value to the console
echo "RUNPOD_TCP_PORT_70000: $PORT_VALUE"

# Write the value to /etc/serverport
echo $PORT_VALUE > /etc/serverport

# Change to the directory containing the Python script
cd /working/runpod-cloudflare-ddns

# Run the Python script
python main.py &

# Start SSH server
/usr/sbin/sshd -D
