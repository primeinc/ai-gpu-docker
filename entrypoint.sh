#!/bin/bash

# Function to export environment variables to .bashrc
export_to_bashrc() {
  local var_name="$1"
  local var_value="${!1}"
  echo "export $var_name=$var_value" >> "/root/.bashrc"
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

# Using the function to export variables to .bashrc
export_to_bashrc "SERVER_PUBLIC_IP"
export_to_bashrc "SERVER_PORT"
export_to_bashrc "SERVER_PORT_2"
export_to_bashrc "SERVER_PORT_3"
export_to_bashrc "RUNPOD_TCP_PORT_70000"
export_to_bashrc "RUNPOD_TCP_PORT_70001"
export_to_bashrc "RUNPOD_TCP_PORT_70002"

echo "$SERVER_PUBLIC_IP" > "/etc/serverpublicip"
echo "$RUNPOD_TCP_PORT_70000" > "/etc/serverport"

echo "SERVER_PUBLIC_IP: $SERVER_PUBLIC_IP"
echo "RUNPOD_TCP_PORT_70000 | SERVER_PORT: $RUNPOD_TCP_PORT_70000"
echo "RUNPOD_TCP_PORT_70001 | SERVER_PORT_2: $RUNPOD_TCP_PORT_70001"
echo "RUNPOD_TCP_PORT_70002 | SERVER_PORT_3: $RUNPOD_TCP_PORT_70002"

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
python "/root/auto_tls.py"
if [ $? -ne 0 ]; then
  echo "Failed to generate web certificate files."
  echo "The following env vars will not be available:"
  echo "SERVER_KEY SERVER_CERT SERVER_BUNDLE"
fi

if command -v runpodctl > /dev/null 2>&1; then
  echo "Runpod's platform detected."
  service ssh start
  # Track commands to estimate idle time
  echo "PROMPT_COMMAND=\"echo \$(date +%s) > /tmp/last_command_time\"" >> "/root/.bashrc"
  while true; do bash ./idlecheck.sh; sleep 5m; done
else
  echo "Not running on Runpod."
  echo "Skipping idlecheck.sh and launching SSH Server."
  /usr/sbin/sshd -D
fi