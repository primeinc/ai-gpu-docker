#!/bin/bash

# Define constants
WORKSPACE_DIR="/workspace/sd-webui"
WEBUI_FILE="$WORKSPACE_DIR/webui.sh"
WEBUI_USER_FILE="$WORKSPACE_DIR/webui-user.sh"

# Replacement values
VENV_DIR="__UNSET__"
USE_ACCELERATE="True"

# Check required variables
check_required_variables() {
  [ -z "$SERVER_NAME" ] && {
    echo "SERVER_NAME is not set"
    exit 1
  }
  [ -z "$SERVER_PORT" ] && {
    echo "SERVER_PORT is not set"
    exit 1
  }
}

# Enable running as root
enable_run_as_root() {
  sed -i 's/can_run_as_root=0/can_run_as_root=1/g' "$WEBUI_FILE"
}

# Update command line args
update_command_line_args() {
  local args="
    --server-name $SERVER_NAME
    --port $SERVER_PORT
    --disable-tls-verify
    --listen
    --api
    --allow-code
    --enable-insecure-extension-access
    --xformers
    --no-progressbar-hiding
    --theme dark
    --upcast-sampling
    "

  # Trim leading and trailing whitespaces and join lines into a single line
  args=$(echo "$args" | tr -d '\n' | sed 's/^[ \t]*//;s/[ \t]*$//;s/[ \t]\+/ /g')

  # Append TLS related args if certs are provided
  if [[ -n "$SERVER_CERT" && -n "$SERVER_KEY" ]]; then
    args="$args --tls-keyfile $SERVER_KEY --tls-certfile $SERVER_CERT"
  fi

  echo "Starting with command line args: $args"
  # Replace or append args in file
  grep -q "COMMANDLINE_ARGS=" "$WEBUI_USER_FILE" &&
    sed -i "s/#\?export COMMANDLINE_ARGS=.*$/export COMMANDLINE_ARGS=\"$args\"/" "$WEBUI_USER_FILE" ||
    echo "export COMMANDLINE_ARGS=\"$args\"" >>"$WEBUI_USER_FILE"
}

# Update other settings
update_other_settings() {
  sed -i "s/#\?venv_dir=.*$/venv_dir=\"$VENV_DIR\"/" "$WEBUI_USER_FILE"
  sed -i "s/#\?export ACCELERATE=.*$/export ACCELERATE=\"$USE_ACCELERATE\"/" "$WEBUI_USER_FILE"
}

# Main script execution
main() {
  check_required_variables
  enable_run_as_root
  update_command_line_args
  update_other_settings

  cd "$WORKSPACE_DIR" || {
    echo "Failed to change directory to $WORKSPACE_DIR"
    exit 1
  }
  chmod +x "$WEBUI_FILE"
  chmod +x "$WEBUI_USER_FILE"
  # cat "$WEBUI_USER_FILE"
  # Execute webui.sh if needed
  bash "$WEBUI_FILE"
}

# Invoke main
main