#!/bin/bash
#
# EBS Volume Mount CLI Script
# This script attaches and mounts an EBS volume to an EC2 instance
#

set -e

# Define console colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Default values - hardcoded
MOUNT_POINT="/data"
FILESYSTEM="ext4"  # Hardcoded to ext4
DEVICE_NAME="/dev/xvdf"  # Default device name for attachment

# Parse command line arguments
usage() {
    echo "Usage: $0 [-v VOLUME_ID] [-d DEVICE_NAME]"
    echo ""
    echo "Options:"
    echo "  -v VOLUME_ID    AWS EBS Volume ID to attach (e.g., vol-0123abcd...)"
    echo "  -d DEVICE_NAME  Device name to use for attachment (default: /dev/xvdf)"
    echo "  -h              Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -v vol-0abc123def456"
    echo "  $0 -v vol-0abc123def456 -d /dev/xvdg"
}

# Parse command line options
while getopts "v:d:h" opt; do
    case $opt in
        v) VOLUME_ID="$OPTARG" ;;
        d) DEVICE_NAME="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# Log file setup
LOG_DIR="/var/log/ebs-mount"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="${LOG_DIR}/mount-${TIMESTAMP}.log"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    echo "Created log directory: $LOG_DIR"
fi

# Function to log messages
log() {
    local message="$1"
    local level="$2"
    local color="${NC}"
    
    case "$level" in
        "INFO") color="${BLUE}" ;;
        "SUCCESS") color="${GREEN}" ;;
        "ERROR") color="${RED}" ;;
        "WARN") color="${YELLOW}" ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}${NC}" | tee -a "$LOG_FILE"
}

# Check and install AWS CLI if not present
ensure_aws_cli() {
    log "Checking for AWS CLI..." "INFO"
    if ! command -v aws &> /dev/null; then
        log "AWS CLI not found. Installing..." "INFO"
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >> "$LOG_FILE" 2>&1
        unzip -q awscliv2.zip >> "$LOG_FILE" 2>&1
        ./aws/install >> "$LOG_FILE" 2>&1
        rm -rf aws awscliv2.zip
        log "AWS CLI installed successfully" "SUCCESS"
    else
        log "AWS CLI already installed" "INFO"
    fi
}

# Get instance metadata
get_instance_metadata() {
    log "Getting EC2 instance metadata..." "INFO"
    
    # Get instance ID
    local TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    
    # Get region from instance metadata
    AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
    AWS_REGION=${AVAILABILITY_ZONE%?}  # Remove the last character (the AZ letter)
    log "Auto-detected AWS region: ${AWS_REGION}" "INFO"
    
    log "Instance ID: ${INSTANCE_ID}" "INFO"
    log "AWS Region: ${AWS_REGION}" "INFO"
}

# Check volume status
check_volume_status() {
    local volume_id="$1"
    log "Checking volume status for ${volume_id}..." "INFO"
    
    local volume_state=$(aws ec2 describe-volumes \
        --volume-ids "$volume_id" \
        --region "$AWS_REGION" \
        --query 'Volumes[0].State' \
        --output text 2>> "$LOG_FILE")
    
    log "Volume state: ${volume_state}" "INFO"
    
    # Check if the volume is already attached to this instance
    local attachment_status=$(aws ec2 describe-volumes \
        --volume-ids "$volume_id" \
        --region "$AWS_REGION" \
        --query "Volumes[0].Attachments[?InstanceId=='$INSTANCE_ID'].State" \
        --output text 2>> "$LOG_FILE")
    
    if [ -n "$attachment_status" ] && [ "$attachment_status" != "None" ]; then
        log "Volume is already attached to this instance with status: ${attachment_status}" "WARN"
        return 0
    elif [ "$volume_state" != "available" ]; then
        log "Volume is not in 'available' state. Current state: ${volume_state}" "ERROR"
        return 1
    fi
    
    return 0
}

# Attach EBS volume to instance
attach_ebs_volume() {
    local volume_id="$1"
    local device_name="$2"
    
    log "Attaching EBS volume ${volume_id} to instance ${INSTANCE_ID} as ${device_name}..." "INFO"
    
    aws ec2 attach-volume \
        --volume-id "$volume_id" \
        --instance-id "$INSTANCE_ID" \
        --device "$device_name" \
        --region "$AWS_REGION" >> "$LOG_FILE" 2>&1
    
    log "Waiting for volume attachment to complete..." "INFO"
    
    aws ec2 wait volume-in-use \
        --volume-ids "$volume_id" \
        --region "$AWS_REGION" >> "$LOG_FILE" 2>&1
    
    # Wait a bit more to ensure the OS recognizes the new device
    sleep 10
    log "Volume attached successfully" "SUCCESS"
}

# Update system
update_system() {
    log "Updating system packages..." "INFO"
    if command -v yum &> /dev/null; then
        yum update -y >> "$LOG_FILE" 2>&1
        
        # Make sure e2fsprogs is installed for ext4 filesystem
        if ! rpm -q e2fsprogs &> /dev/null; then
            log "Installing e2fsprogs package for ext4 filesystem support..." "INFO"
            yum install -y e2fsprogs >> "$LOG_FILE" 2>&1
        fi
    elif command -v apt-get &> /dev/null; then
        apt-get update >> "$LOG_FILE" 2>&1
        apt-get upgrade -y >> "$LOG_FILE" 2>&1
        
        # Make sure e2fsprogs is installed for ext4 filesystem
        if ! dpkg -l | grep -q e2fsprogs; then
            log "Installing e2fsprogs package for ext4 filesystem support..." "INFO"
            apt-get install -y e2fsprogs >> "$LOG_FILE" 2>&1
        fi
    else
        log "Unsupported package manager. Skipping system update." "WARN"
        return 1
    fi
    log "System update completed" "SUCCESS"
}

# Function to detect EBS volume device
detect_ebs_device() {
    log "Detecting attached EBS volume..." "INFO"
    
    # For volumes attached via AWS CLI, we need to map between the requested device
    # and the actual device that shows up on the instance
    
    # Check if we're on a Nitro-based instance
    if [ -d "/sys/devices/virtual/nvme" ]; then
        log "Nitro-based instance detected, scanning for NVMe devices..." "INFO"
        
        # Try to find the device using nvme-cli if available
        if command -v nvme &> /dev/null; then
            local nvme_devices=$(nvme list -o json 2>> "$LOG_FILE" || echo '{"Devices":[]}')
            
            # If we have a volume ID, search for it specifically
            if [ -n "$VOLUME_ID" ]; then
                EBS_DEVICE=$(echo "$nvme_devices" | grep -o "nvme[0-9]n[0-9].*$VOLUME_ID" | awk '{print "/dev/"$1}' | head -1)
                if [ -n "$EBS_DEVICE" ]; then
                    log "Found EBS volume $VOLUME_ID at device $EBS_DEVICE" "SUCCESS"
                    return 0
                fi
            fi
        fi
        
        # If nvme-cli didn't find it or isn't available, check common locations
        for i in {0..9}; do
            if [ -b "/dev/nvme${i}n1" ]; then
                # Check if this device is already mounted
                if ! mount | grep -q "/dev/nvme${i}n1"; then
                    EBS_DEVICE="/dev/nvme${i}n1"
                    log "Selected EBS volume at ${EBS_DEVICE}" "SUCCESS"
                    return 0
                fi
            fi
        done
    else
        # For non-Nitro instances, check standard device naming
        log "Standard EC2 instance detected, checking for standard device naming..." "INFO"
        
        # The device name we requested might be different from what shows up in the OS
        local requested_suffix="${DEVICE_NAME##*/}"  # Get 'xvdf' from '/dev/xvdf'
        
        # Check if the device exists as requested
        if [ -b "/dev/$requested_suffix" ]; then
            EBS_DEVICE="/dev/$requested_suffix"
            log "Found EBS volume at ${EBS_DEVICE}" "SUCCESS"
            return 0
        fi
        
        # Check with 'xvd' prefix (common AWS mapping)
        if [ -b "/dev/xvd${requested_suffix:(-1)}" ]; then
            EBS_DEVICE="/dev/xvd${requested_suffix:(-1)}"
            log "Found EBS volume at ${EBS_DEVICE}" "SUCCESS"
            return 0
        fi
        
        # Check sd* devices (older instances)
        if [ -b "/dev/sd${requested_suffix:(-1)}" ]; then
            EBS_DEVICE="/dev/sd${requested_suffix:(-1)}"
            log "Found EBS volume at ${EBS_DEVICE}" "SUCCESS"
            return 0
        fi
    fi
    
    # List all available block devices for debugging
    log "Listing all available block devices:" "INFO"
    lsblk -d -o NAME,TYPE,SIZE,MOUNTPOINT >> "$LOG_FILE"
    lsblk -d -o NAME,TYPE,SIZE,MOUNTPOINT
    
    log "No suitable EBS volume device detected" "ERROR"
    return 1
}

# Function to create filesystem if needed
create_filesystem() {
    log "Checking if filesystem exists on ${EBS_DEVICE}..." "INFO"
    
    # Check if device already has a filesystem
    if blkid "$EBS_DEVICE" >> "$LOG_FILE" 2>&1; then
        log "Filesystem already exists on ${EBS_DEVICE}" "WARN"
    else
        log "Creating ${FILESYSTEM} filesystem on ${EBS_DEVICE}..." "INFO"
        
        # Create ext4 filesystem
        mkfs.ext4 "$EBS_DEVICE" >> "$LOG_FILE" 2>&1
        log "Filesystem created successfully" "SUCCESS"
    fi
}

# Function to mount the volume
mount_volume() {
    log "Creating mount point at ${MOUNT_POINT}" "INFO"
    
    # Create mount point if it doesn't exist
    if [ ! -d "$MOUNT_POINT" ]; then
        mkdir -p "$MOUNT_POINT"
        chmod 755 "$MOUNT_POINT"
        log "Created mount directory at ${MOUNT_POINT}" "INFO"
    fi
    
    # Check if already mounted
    if grep -qs "$MOUNT_POINT" /proc/mounts; then
        log "A filesystem is already mounted at ${MOUNT_POINT}" "WARN"
        return 1
    fi
    
    # Mount the volume
    log "Mounting ${EBS_DEVICE} to ${MOUNT_POINT}..." "INFO"
    mount -t ext4 "$EBS_DEVICE" "$MOUNT_POINT" >> "$LOG_FILE" 2>&1
    
    # Get the UUID of the device
    UUID=$(blkid -s UUID -o value "$EBS_DEVICE")
    
    # Add to fstab for persistence across reboots
    if ! grep -q "$UUID" /etc/fstab; then
        log "Adding mount entry to /etc/fstab for persistence..." "INFO"
        echo "UUID=${UUID} ${MOUNT_POINT} ${FILESYSTEM} defaults 0 2" >> /etc/fstab
    fi
    
    log "Setting appropriate permissions..." "INFO"
    
    # Check if ec2-user exists and set ownership
    if id "ec2-user" &> /dev/null; then
        chown ec2-user:ec2-user "$MOUNT_POINT"
    fi
    
    log "EBS volume successfully mounted at ${MOUNT_POINT}" "SUCCESS"
}

# Function to display mount information
display_mount_info() {
    log "Current mount information:" "INFO"
    df -h | grep "$MOUNT_POINT" >> "$LOG_FILE" || true
    df -h | grep "$MOUNT_POINT" || true
    
    if [ -e "$EBS_DEVICE" ]; then
        log "Volume UUID: $(blkid -s UUID -o value "$EBS_DEVICE" 2>/dev/null || echo "N/A")" "INFO"
        log "Filesystem type: $(blkid -s TYPE -o value "$EBS_DEVICE" 2>/dev/null || echo "N/A")" "INFO"
    fi
}

# Main execution function
main() {
    log "Starting EBS volume mount process" "INFO"
    log "Mount point set to: ${MOUNT_POINT}" "INFO"
    log "Filesystem type: ${FILESYSTEM}" "INFO"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        log "This script must be run as root" "ERROR"
        exit 1
    fi
    
    # Install AWS CLI if needed
    ensure_aws_cli
    
    # Get instance metadata
    get_instance_metadata
    
    # If volume ID is provided, attach the volume
    if [ -n "$VOLUME_ID" ]; then
        log "Volume ID provided: ${VOLUME_ID}" "INFO"
        
        # Check if the volume is available and not already attached
        if check_volume_status "$VOLUME_ID"; then
            # If the volume is available, attach it
            if ! echo "$VOLUME_ID" | grep -q "vol-"; then
                log "Invalid volume ID format. Expected format: vol-xxxxxxxxxxxxxxxxx" "ERROR"
                exit 1
            fi
            
            # Attach the EBS volume
            attach_ebs_volume "$VOLUME_ID" "$DEVICE_NAME"
        else
            log "Volume is not available for attachment. Check AWS Console." "ERROR"
            exit 1
        fi
    else
        log "No volume ID provided. Will attempt to mount an already attached volume." "INFO"
    fi
    
    # Update system
    update_system
    
    # Detect EBS device
    if ! detect_ebs_device; then
        log "No suitable EBS device found to mount. Check that the volume is attached correctly." "ERROR"
        exit 1
    fi
    
    # Create filesystem if needed
    create_filesystem
    
    # Mount the volume
    mount_volume
    
    # Display mount information
    display_mount_info
    
    log "EBS volume mount process completed successfully" "SUCCESS"
    log "Log file available at: $LOG_FILE" "INFO"
    
    # Create a symlink to the latest log for easy access
    ln -sf "$LOG_FILE" "${LOG_DIR}/latest.log"
}

# Execute the main function
main "$@"