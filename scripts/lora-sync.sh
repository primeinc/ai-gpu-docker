#!/bin/bash

# Define the source and destination paths
SOURCE_DIR="/workspace/models/lora"
DEST_DIR="/tmp/lora_cache" # You can adjust this path as needed
RSYNC_ARGS="-a --whole-file --stats --human-readable --info=progress2"

# Check if source directory exists
if [[ ! -d $SOURCE_DIR ]]; then
    echo "Source directory $SOURCE_DIR does not exist. Aborting."
    exit 1
fi

display_menu() {
    echo "Please choose an option:"
    echo "1) Rsync all files"
    echo "2) Rsync files from the last 'n' days"
    echo "3) Rsync files and folders matching a prefix"
    echo "4) Rsync changes back to network storage"
    echo "5) Exit"
    read -p "Enter your choice (1/2/3/4/5): " choice
}

while true; do
    display_menu

    case $choice in
    1)
        rsync $RSYNC_ARGS $SOURCE_DIR/ $DEST_DIR/
        ;;
    2)
        read -p "Enter number of days: " days
        (cd $SOURCE_DIR && find . -mtime -$days) >/tmp/recent_files.txt
        rsync $RSYNC_ARGS --files-from=/tmp/recent_files.txt $SOURCE_DIR/ $DEST_DIR/
        rm -f /tmp/recent_files.txt
        ;;
    3)
        read -p "Enter the prefix (e.g., kj-od, odp_, kjo): " prefix
        (cd $SOURCE_DIR && find . -name "${prefix}*") >/tmp/prefix_files.txt
        rsync $RSYNC_ARGS --files-from=/tmp/prefix_files.txt $SOURCE_DIR/ $DEST_DIR/
        rm -f /tmp/prefix_files.txt
        ;;
    4)
        rsync $RSYNC_ARGS $DEST_DIR/ $SOURCE_DIR/
        ;;
    5)
        echo "Goodbye!"
        ;;
    *)
        echo "Invalid choice."
        ;;
    esac

    exit 0

done
