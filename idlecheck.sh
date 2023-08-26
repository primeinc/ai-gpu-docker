#!/bin/bash

# File to store the last command time
LAST_COMMAND_TIME_FILE="/tmp/last_command_time"

# Function to get system uptime in minutes and convert to hours
get_uptime_hours() {
  awk '{print ($1/60/60)}' /proc/uptime
}

# Check if IDLE_KILL_HOURS and IDLE_STOP_HOURS are set
if [ -z "$IDLE_KILL_HOURS" ] && [ -z "$IDLE_STOP_HOURS" ]; then
  echo "IDLE_KILL_HOURS or IDLE_STOP_HOURS is not set."
  echo "Not checking for idle time, pod will remain on indefinitely."
  exit 0
fi

echo "IDLE_KILL_HOURS: $IDLE_KILL_HOURS | IDLE_STOP_HOURS: $IDLE_STOP_HOURS"

# Read the last command time and calculate time since last command in hours
if [ -f "$LAST_COMMAND_TIME_FILE" ]; then
  last_command_time=$(cat "$LAST_COMMAND_TIME_FILE")
else
  last_command_time=$(date +%s)
fi
current_time=$(date +%s)
time_since_last_command=$(awk -v ct="$current_time" -v lt="$last_command_time" 'BEGIN {print (ct - lt) / 60 / 60}')

# Debug: Show time_since_last_command
echo "Time since last command: $time_since_last_command hours"

# Check uptime in hours
uptime_hours=$(get_uptime_hours)

# Only proceed with IDLE_KILL_HOURS if set and greater than 0
if [ ! -z "$IDLE_KILL_HOURS" ] && awk 'BEGIN {exit !('$IDLE_KILL_HOURS' > 0)}'; then
  if awk 'BEGIN {exit !('$uptime_hours' > '$IDLE_KILL_HOURS' && '$time_since_last_command' > '$IDLE_KILL_HOURS')}' ; then
    echo "System has been up and idle for more than $IDLE_KILL_HOURS hours. Removing the pod."
    runpodctl remove pod $RUNPOD_POD_ID
    exit 0
  fi
fi

# Only proceed with IDLE_STOP_HOURS if set and greater than 0
if [ ! -z "$IDLE_STOP_HOURS" ] && awk 'BEGIN {exit !('$IDLE_STOP_HOURS' > 0)}'; then
  if awk 'BEGIN {exit !('$uptime_hours' > '$IDLE_STOP_HOURS' && '$time_since_last_command' > '$IDLE_STOP_HOURS')}' ; then
    echo "System has been up and idle for more than $IDLE_STOP_HOURS hours. Stopping the pod."
    runpodctl stop pod $RUNPOD_POD_ID
    exit 0
  fi
fi

echo "Not idle for the required time. Continuing."