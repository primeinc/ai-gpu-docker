#!/bin/bash

# Function to export environment variables to .bashrc
export_to_bashrc() {
  local var_name="$1"
  local var_value="${!1}"
  echo "export $var_name=\"$var_value\"" >> "/root/.bashrc"
  export $var_name="$var_value"
}

for key in "$PUBLIC_KEY" "$RUNPOD_SSH_PUBLIC_KEY"; do
  if [ -n "$key" ]; then
    echo "$key" >> "/root/.ssh/authorized_keys"
  fi
done

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

echo "$SERVER_PUBLIC_IP" > "/etc/serverpublicip"
echo "$SERVER_PORT" > "/etc/serverport"

echo "SERVER_PUBLIC_IP: $SERVER_PUBLIC_IP"
echo "RUNPOD_TCP_PORT_70000 | SERVER_PORT: $RUNPOD_TCP_PORT_70000"
echo "RUNPOD_TCP_PORT_70001 | SERVER_PORT_2: $RUNPOD_TCP_PORT_70001"
echo "RUNPOD_TCP_PORT_70002 | SERVER_PORT_3: $RUNPOD_TCP_PORT_70002"
echo "RUNPOD_TCP_PORT_70003 | SERVER_PORT_4: $RUNPOD_TCP_PORT_70003"

if [ $ENABLE_DDNS ]; then
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
  python main.py
  if [ $? -ne 0 ]; then
    echo "Unable to retrieve DDNS domain name."
    echo "Bypassing configuration and launching SSH Server."
    /usr/sbin/sshd -D
    exit 1
  fi
  SERVER_NAME=$(cat /etc/servername)
  echo "SERVER_NAME: $SERVER_NAME"
  export_to_bashrc "SERVER_NAME"
  echo "0.0.0.0 $SERVER_NAME" >> /etc/hosts
else
  echo "DDNS is disabled, using public IP as servername."
  echo "SERVER_NAME: $SERVER_PUBLIC_IP"
  echo "$SERVER_PUBLIC_IP" > "/etc/servername"
  echo "export SERVER_NAME=$SERVER_PUBLIC_IP" >> "/root/.bashrc"
fi

# Generate tls certificate files
# Will export the following variables: SERVER_KEY SERVER_CERT SERVER_BUNDLE
cd ~

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
' >> /root/.bashrc

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
' > /root/.cache/huggingface/accelerate/default_config.yaml

LD_PRELOAD=libtcmalloc.so
PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
CUDNN_PATH=$(dirname $(python -c "import nvidia.cudnn;print(nvidia.cudnn.__file__)"))
export LD_LIBRARY_PATH=$CUDNN_PATH/lib:$LD_LIBRARY_PATH

python "/root/auto_tls.py"
if [ $? -ne 0 ]; then
  echo "Failed to generate web certificate files."
  echo "The following env vars will not be available:"
  echo "SERVER_KEY SERVER_CERT SERVER_BUNDLE"
fi

if command -v runpodctl > /dev/null 2>&1; then
  echo "Runpod's platform detected."
  service ssh start
  while true; do bash ./idlecheck.sh; sleep 5m; done
else
  echo "Not running on Runpod."
  echo "Skipping idlecheck.sh and launching SSH Server."
  /usr/sbin/sshd -D
fi