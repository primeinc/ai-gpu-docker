#!/bin/bash

# Function to export environment variables to .bashrc
export_to_bashrc() {
  local var_name="$1"
  local var_value="${!1}"
  echo "export $var_name=\"$var_value\"" >>"/root/.bashrc"
  export $var_name="$var_value"
}

save_to_bashrc() {
  local var="$1"
  echo "$var" >>"/root/.bashrc"
}

for key in "$PUBLIC_KEY" "$RUNPOD_SSH_PUBLIC_KEY"; do
  if [ -n "$key" ]; then
    echo "$key" >>"/root/.ssh/authorized_keys"
  fi
done

echo $(date +%s) >/tmp/container_start_time

# Get the IP address & 1:1 ports of the container
SERVER_PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ $? -ne 0 ]; then
  echo "Unable to retrieve public IP address. Bypassing configuration and launching SSH Server."
  /usr/sbin/sshd -D
  exit 1
fi
SERVER_PORT=${RUNPOD_TCP_PORT_70000:-7860}
SERVER_PORT_2=${RUNPOD_TCP_PORT_70001:-7861}
SERVER_PORT_3=${RUNPOD_TCP_PORT_70002:-7862}
SERVER_PORT_4=${RUNPOD_TCP_PORT_70003:-7863}

TF_CPP_MIN_LOG_LEVEL=2
LD_PRELOAD=libtcmalloc.so
PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
CUDNN_PATH=$(dirname $(python -c "import nvidia.cudnn;print(nvidia.cudnn.__file__)"))
LD_LIBRARY_PATH=$CUDNN_PATH/lib:$LD_LIBRARY_PATH

# Using the function to export variables to .bashrc
export_to_bashrc "SERVER_PUBLIC_IP"
export_to_bashrc "SERVER_PORT"
export_to_bashrc "SERVER_PORT_2"
export_to_bashrc "SERVER_PORT_3"
export_to_bashrc "SERVER_PORT_4"
export_to_bashrc "RUNPOD_TCP_PORT_70000"
export_to_bashrc "RUNPOD_TCP_PORT_70001"
export_to_bashrc "RUNPOD_TCP_PORT_70002"
export_to_bashrc "RUNPOD_TCP_PORT_70003"
export_to_bashrc "LD_PRELOAD"
export_to_bashrc "PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"
export_to_bashrc "TF_CPP_MIN_LOG_LEVEL"
export_to_bashrc "LD_LIBRARY_PATH"
echo "set completion-ignore-case on" >>/root/.inputrc
save_to_bashrc "alias run-sdweb=\"bash /root/scripts/start-sdweb.sh\""
save_to_bashrc "alias run-lora-sdweb=\"bash /root/scripts/start-sdweb.sh --lora-cache\""
save_to_bashrc "alias run-roop=\"bash /workspace/roop.sh\""
save_to_bashrc "alias run-syncthing=\"bash /workspace/syncthing.sh\""
save_to_bashrc "alias lora-sync=\"bash /root/scripts/lora-sync.sh\""
save_to_bashrc "alias cd-sdweb=\"cd /workspace/sd-webui\""
save_to_bashrc "alias cd-roop=\"cd /workspace/roop-unleashed\""
save_to_bashrc "alias cd-syncthing=\"cd /workspace/syncthing\""
save_to_bashrc "cd /workspace"
save_to_bashrc '
    if [ -e /root/banner.sh ]
    then
      chmod 755 /root/banner.sh
      bash /root/banner.sh
    fi
'
save_to_bashrc '
IDLE_KILL_MINUTES_FILE="/tmp/idle_kill_minutes"
IDLE_STOP_MINUTES_FILE="/tmp/idle_stop_minutes"

function kill-minutes()
{
  if [[ -z $1 ]]; then
    echo "Please provide the number of minutes for IDLE_KILL_MINUTES."
    return 1
  fi
  echo "$1" > "$IDLE_KILL_MINUTES_FILE"
  echo "IDLE_KILL_MINUTES set to $1"
}

function stop-minutes()
{
  if [[ -z $1 ]]; then
    echo "Please provide the number of minutes for IDLE_STOP_MINUTES."
    return 1
  fi
  echo "$1" > "$IDLE_STOP_MINUTES_FILE"
  echo "IDLE_STOP_MINUTES set to $1"
}
'

echo "$SERVER_PUBLIC_IP" >"/etc/serverpublicip"
echo "$SERVER_PORT" >"/etc/serverport"

echo "SERVER_PUBLIC_IP: $SERVER_PUBLIC_IP"
echo "RUNPOD_TCP_PORT_70000 | SERVER_PORT: $RUNPOD_TCP_PORT_70000"
echo "RUNPOD_TCP_PORT_70001 | SERVER_PORT_2: $RUNPOD_TCP_PORT_70001"
echo "RUNPOD_TCP_PORT_70002 | SERVER_PORT_3: $RUNPOD_TCP_PORT_70002"
echo "RUNPOD_TCP_PORT_70003 | SERVER_PORT_4: $RUNPOD_TCP_PORT_70003"

if [ "$ENABLE_DDNS" = "true" ] || [ "$ENABLE_DDNS" = "1" ]; then
  echo "DDNS is enabled."
  echo "Checking for updates to DDNS app."
  NETWORK_DIR=${NETWORK_DIR:-/workspace}
  DDNS_GIT_DIR_NAME=${DDNS_GIT_DIR_NAME:-runpod-cloudflare-ddns}
  DDNS_GIT_DIR="$NETWORK_DIR/$DDNS_GIT_DIR_NAME"
  DDNS_REPO_URL=${DDNS_REPO_URL:-https://github.com/primeinc/runpod-cloudflare-ddns.git}

  # Check if the directory exists and is a git repository
  if [ -d "$DDNS_GIT_DIR/.git" ]; then
    # Change to the directory
    cd "$DDNS_GIT_DIR"

    # Try to pull updates
    git pull || {
      # If pull fails, stash changes and try again
      git stash && git pull || {
        # If pull still fails, remove the directory and clone fresh

        # TODO: This is a bad idea, as it will remove any local changes
        # and remove the config file as well. Need to find a better way.
        echo "Failed to pull updates, continuing."
        # Additionally, we have provided no way to configure the
        # DDNS app if it wasn't previously configured.
      }
    }
  else
    # Clone the repository
    git clone "$DDNS_REPO_URL" "$DDNS_GIT_DIR"
  fi
  # Change to the directory
  cd "$DDNS_GIT_DIR"
  # Generate a DDNS fqdn
  timeout 60s python main.py
  if [ $? -ne 0 ]; then
    if [ $? -eq 124 ]; then
      echo "Timeout occurred after 30 seconds."
    else
      echo "60 second timeout, unable to retrieve DDNS domain name."
    fi
    echo "Bypassing DDNS configuration and continuing."
    unset ENABLE_DDNS
  else
    SERVER_NAME=$(cat /etc/servername)
    echo "SERVER_NAME: $SERVER_NAME"
    export_to_bashrc "SERVER_NAME"
    echo "0.0.0.0 $SERVER_NAME" >>/etc/hosts
  fi

fi

if [ -z "$ENABLE_DDNS" ] || [ "$ENABLE_DDNS" = "false" ] || [ "$ENABLE_DDNS" = "0" ]; then
  SERVER_PUBLIC_IP="0.0.0.0"
  SERVER_NAME="0.0.0.0"
  echo "$SERVER_NAME" >"/etc/servername"
  echo "DDNS is disabled, using $SERVER_NAME as servername & public ip."
  export_to_bashrc "SERVER_NAME"
  export_to_bashrc "SERVER_PUBLIC_IP"
fi

# Generate tls certificate files
# Will export the following variables: SERVER_KEY SERVER_CERT SERVER_BUNDLE
cd ~

git config --global core.autocrlf input
git config --global core.eol lf

# Create a shared bash history file
echo '
# Check if the shared bash history exists; if not, create it
if [ ! -f "/workspace/.bash_history_shared" ]; then
    touch /workspace/.bash_history_shared
fi

# Symlink the shared history file to the home directory
ln -sf /workspace/.bash_history_shared ~/.bash_history

# Update the history file in real-time
PROMPT_COMMAND="echo \$(date +%s) > /tmp/last_command_time; history -a; $PROMPT_COMMAND"
' >>/root/.bashrc

mkdir -p /root/.cache/huggingface/accelerate

echo '
compute_environment: LOCAL_MACHINE
distributed_type: 'NO'
downcast_bf16: 'no'
gpu_ids: all
machine_rank: 0
main_training_function: main
mixed_precision: bf16
num_machines: 1
num_processes: 1
rdzv_backend: static
same_network: true
tpu_env: []
tpu_use_cluster: false
tpu_use_sudo: false
use_cpu: false
' >/root/.cache/huggingface/accelerate/default_config.yaml

python "/root/auto_tls.py"
if [ $? -ne 0 ]; then
  echo "Failed to generate web certificate files."
  echo "The following env vars will not be available:"
  echo "SERVER_KEY SERVER_CERT SERVER_BUNDLE"
fi

if command -v runpodctl >/dev/null 2>&1; then
  echo "Runpod's platform detected."
  service ssh start
  tail -n 1000 /workspace/idlecheck.log >/workspace/temp.log && mv /workspace/temp.log /workspace/idlecheck.log
  while true; do
    bash ./idlecheck.sh
    sleep 1m
  done
else
  echo "Not running on Runpod."
  echo "Skipping idlecheck.sh and launching SSH Server."
  /usr/sbin/sshd -D
fi
