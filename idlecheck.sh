#!/bin/bash

# File to store the last command time
LAST_COMMAND_TIME_FILE="/tmp/last_command_time"

# File to store IDLE_KILL_HOURS and IDLE_STOP_HOURS
IDLE_KILL_HOURS_FILE="/tmp/idle_kill_hours"
IDLE_STOP_HOURS_FILE="/tmp/idle_stop_hours"

# Function to get system uptime in minutes and convert to hours
get_uptime_hours() {
  awk '{print ($1/60/60)}' /proc/uptime
}

# Create files for IDLE_KILL_HOURS and IDLE_STOP_HOURS if they don't exist
[ ! -f "$IDLE_KILL_HOURS_FILE" ] && echo "$IDLE_KILL_HOURS" > "$IDLE_KILL_HOURS_FILE"
[ ! -f "$IDLE_STOP_HOURS_FILE" ] && echo "$IDLE_STOP_HOURS" > "$IDLE_STOP_HOURS_FILE"

# Read IDLE_KILL_HOURS and IDLE_STOP_HOURS from files
IDLE_KILL_HOURS=$(cat "$IDLE_KILL_HOURS_FILE")
IDLE_STOP_HOURS=$(cat "$IDLE_STOP_HOURS_FILE")

# Log the settings for debugging
echo "SERVER_NAME: $SERVER_NAME | SERVER_PUBLIC_IP: $SERVER_PUBLIC_IP"
echo "IDLE_KILL_HOURS: $IDLE_KILL_HOURS | IDLE_STOP_HOURS: $IDLE_STOP_HOURS"

# Check uptime in hours
uptime_hours=$(get_uptime_hours)
echo "Time since last command: $uptime_hours hours"

# Only proceed with IDLE_KILL_HOURS if set and greater than 0
if [ -n "$IDLE_KILL_HOURS" ] && awk -v x="$IDLE_KILL_HOURS" 'BEGIN {exit !(x > 0)}'; then
  if awk -v x="$uptime_hours" -v y="$IDLE_KILL_HOURS" -v z="$time_since_last_command" 'BEGIN {exit !(x > y && z > y)}'; then
    echo "System has been up and idle for more than $IDLE_KILL_HOURS hours. Removing the pod."
    runpodctl remove pod "$RUNPOD_POD_ID"
    exit 0
  fi
fi

# Only proceed with IDLE_STOP_HOURS if set and greater than 0
if [ -n "$IDLE_STOP_HOURS" ] && awk -v x="$IDLE_STOP_HOURS" 'BEGIN {exit !(x > 0)}'; then
  if awk -v x="$uptime_hours" -v y="$IDLE_STOP_HOURS" -v z="$time_since_last_command" 'BEGIN {exit !(x > y && z > y)}'; then
    echo "System has been up and idle for more than $IDLE_STOP_HOURS hours. Stopping the pod."
    runpodctl stop pod "$RUNPOD_POD_ID"
    exit 0
  fi
fi


echo "Not idle for the required time. Continuing."