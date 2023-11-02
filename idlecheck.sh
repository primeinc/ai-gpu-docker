#!/bin/bash

# File to store the last command time
LAST_COMMAND_TIME_FILE="/tmp/last_command_time"

# File to store IDLE_KILL_MINUTES and IDLE_STOP_MINUTES
IDLE_KILL_MINUTES_FILE="/tmp/idle_kill_minutes"
IDLE_STOP_MINUTES_FILE="/tmp/idle_stop_minutes"

# Function to get system uptime in seconds and convert to minutes
calculate_uptime_minutes() {
  start_time=$(cat /tmp/container_start_time)
  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
  elapsed_minutes=$((elapsed_time / 60))
  echo $elapsed_minutes
}

# Create files for IDLE_KILL_MINUTES and IDLE_STOP_MINUTES if they don't exist
[ ! -f "$IDLE_KILL_MINUTES_FILE" ] && echo "$IDLE_KILL_MINUTES" >"$IDLE_KILL_MINUTES_FILE"
[ ! -f "$IDLE_STOP_MINUTES_FILE" ] && echo "$IDLE_STOP_MINUTES" >"$IDLE_STOP_MINUTES_FILE"

# Read IDLE_KILL_MINUTES and IDLE_STOP_MINUTES from files
IDLE_KILL_MINUTES=$(cat "$IDLE_KILL_MINUTES_FILE")
IDLE_STOP_MINUTES=$(cat "$IDLE_STOP_MINUTES_FILE")

# Log the settings for debugging
echo "SERVER_NAME: $SERVER_NAME | SERVER_PUBLIC_IP: $SERVER_PUBLIC_IP"
echo "SERVER_NAME: $SERVER_NAME | SERVER_PUBLIC_IP: $SERVER_PUBLIC_IP" >>/workspace/idlecheck.log
echo "IDLE_KILL_MINUTES: $IDLE_KILL_MINUTES | IDLE_STOP_MINUTES: $IDLE_STOP_MINUTES"
echo "IDLE_KILL_MINUTES: $IDLE_KILL_MINUTES | IDLE_STOP_MINUTES: $IDLE_STOP_MINUTES" >>/workspace/idlecheck.log

# Check uptime in minutes
uptime_minutes=$(calculate_uptime_minutes)
echo "Time since last command: $uptime_minutes minutes"
echo "Time since last command: $uptime_minutes minutes" >>/workspace/idlecheck.log

if [ "$IDLE_KILL_MINUTES" -ne 0 ] && [ "$uptime_minutes" -gt "$IDLE_KILL_MINUTES" ]; then
  echo "System has been up and idle for more than $IDLE_KILL_MINUTES minutes. Removing the pod($RUNPOD_POD_ID)." >>/workspace/idlecheck.log
  runpodctl stop pod "$RUNPOD_POD_ID"
  exit 0
fi

if [ "$IDLE_STOP_MINUTES" -ne 0 ] && [ "$uptime_minutes" -gt "$IDLE_STOP_MINUTES" ]; then
  echo "System has been up and idle for more than $IDLE_STOP_MINUTES minutes. Stopping the pod($RUNPOD_POD_ID)." >>/workspace/idlecheck.log
  runpodctl remove pod "$RUNPOD_POD_ID"
  exit 0
fi

echo "Not idle for the required time. Continuing."
