#!/bin/bash

# This script will try to mount a folder on your NAS to a mount point you specify on linux
# It will
# 1. Attempt to install cifs-utils
# 2. mkdir your mountpoint
# 3. Create a new file at credential localtion you declared
# 4. Add username and password to credential file created in 3
# 5. Backup your fstab file to ./fstab.bak
# 6. Add entry to /etc/fstab for the mount
# 7. Reload systemdaemon

# Variables (Replace these with your actual values)
# Find your NAS IP, for synology you can go to https://finds.synology.com/
NAS_IP="192.168.***.***"
# On your NAS, the folder you want to mount to linux
SHARED_FOLDER="VideoAsset"
# on linux, where you want to mount the drive
MOUNT_POINT="/mnt/VideoAsset"
# on linux, who should be the owner of this mount, you can check with id
USERNAME="your_username"
GROUPNAME="your_main_group"
# credentials to login to nas, you can chose other locations than samba
CREDENTIALS_DIR="/etc/samba"
CREDENTIALS_FILE="$CREDENTIALS_DIR/credentials"
SYNOLOGY_USERNAME="your_nas_username"
SYNOLOGY_PASSWORD="your_nas_password"
# when --dryrun is provided, we won't execute these commands instead we will print them out
DRYRUN=false

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    --dryrun)
      DRYRUN=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Function to execute commands with optional dry run
execute() {
  if [ "$DRYRUN" = true ]; then
    echo "[DRY RUN] $@"
  else
    eval "$@"
  fi
}

# Check if running as root
if [ "$DRYRUN" = false ] && [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Install cifs-utils, this would work for archlinux, for other distro you might want to see
# what package is used for cifs/samba
echo "Installing cifs-utils..."
execute "pacman -S --noconfirm cifs-utils"

# Create mount point
echo "Creating mount point at $MOUNT_POINT..."
execute "mkdir -p $MOUNT_POINT"

# Create credentials file
echo "Creating credentials file at $CREDENTIALS_FILE..."
execute "mkdir -p $CREDENTIALS_DIR"

# !!!IMPORTANT: this line will clear your original CREDENTIALS_FILE
execute "echo \"username=$SYNOLOGY_USERNAME\" > $CREDENTIALS_FILE"
execute "echo \"password=$SYNOLOGY_PASSWORD\" >> $CREDENTIALS_FILE"

# Secure the credentials file
echo "Securing the credentials file..."
execute "chmod 600 $CREDENTIALS_FILE"

# Back up fstab
echo "Backing up fstab to ./fstab.bak"
execute "cp /etc/fstab ./fstab.bak" 

# Add entry to /etc/fstab
FSTAB_ENTRY="//${NAS_IP}/${SHARED_FOLDER} ${MOUNT_POINT} cifs credentials=${CREDENTIALS_FILE},iocharset=utf8,uid=${USERNAME},gid=${GROUPNAME},file_mode=0770,dir_mode=0770,_netdev,x-systemd.automount 0 0"
if ! grep -qxF "$FSTAB_ENTRY" /etc/fstab; then
  echo "Entry does not exist, adding entry to /etc/fstab..."
  execute "echo -e >> /etc/fstab"
  execute "echo -e \"$FSTAB_ENTRY\" >> /etc/fstab"
else
  echo "Entry already exists in /etc/fstab"
fi

# Reload systemd daemon
echo "Reloading systemd daemon..."
execute "systemctl daemon-reload"

echo -e
echo -e "credential: $CREDENTIALS_FILE"
echo -e "fstab: /etc/fstab"
echo -e "mount_point: $MOUNT_POINT"
echo -e "Finished, exiting..."
echo -e "You can reboot now"
echo -e
