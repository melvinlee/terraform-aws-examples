#!/bin/bash

# Update system packages
yum update -y

# Install Python pip
yum install -y python3-pip

# Install Ansible
pip3 install ansible

# Ensure log directory exists before writing to it
if [ ! -d "/var/log/ansible" ]; then
    mkdir -p /var/log/ansible
    chmod 755 /var/log/ansible
    echo "Created log directory: /var/log/ansible"
fi

# Install AWS collection for Ansible
ansible-galaxy collection install amazon.aws

# Create directory for Ansible playbooks
mkdir -p /opt/ansible/playbooks

# Create Ansible playbook to install AWS dependencies
cat > /opt/ansible/playbooks/install_aws_deps.yml << 'EOF'
---
- name: Install Python AWS dependencies
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Install Python dependencies for AWS modules
      pip:
        name:
          - boto3
          - botocore
          - pywinrm  # For Windows remote management
        state: present

    - name: Check installation
      command: pip3 list | grep boto
      register: pip_check
      changed_when: false

    - name: Show installed packages
      debug:
        var: pip_check.stdout_lines
EOF

# Copy the EBS volume mounting playbook
cat > /opt/ansible/playbooks/mount-data-volume.yml << 'EOF'
---
- name: Mount EBS data volume to /data
  hosts: localhost
  connection: local
  become: yes
  gather_facts: yes
  tasks:
    - name: Check if the device exists
      stat:
        path: /dev/nvme1n1
      register: nvme_device

    - name: Check if xvdf device exists (older instance types)
      stat:
        path: /dev/xvdf
      register: xvdf_device
      when: not nvme_device.stat.exists

    - name: Set device path for NVME (newer instances)
      set_fact:
        device_path: /dev/nvme1n1
      when: nvme_device.stat.exists

    - name: Set device path for xvdf (older instances)
      set_fact:
        device_path: /dev/xvdf
      when: not nvme_device.stat.exists and xvdf_device.stat.exists

    - name: Fail if no device is found
      fail:
        msg: "Could not find the EBS volume device"
      when: 
        - not nvme_device.stat.exists
        - not xvdf_device.stat.exists | default(false)

    - name: Create filesystem on the EBS volume if it doesn't have one
      filesystem:
        fstype: xfs
        dev: "{{ device_path }}"
      when: device_path is defined

    - name: Create mount directory
      file:
        path: /data
        state: directory
        mode: '0755'

    - name: Mount EBS volume
      mount:
        path: /data
        src: "{{ device_path }}"
        fstype: xfs
        state: mounted

    - name: Set appropriate permissions
      file:
        path: /data
        owner: ec2-user
        group: ec2-user
        mode: '0755'
        state: directory

    - name: Check mount point
      command: df -h
      register: df_output
      changed_when: false

    - name: Display mounted volumes
      debug:
        var: df_output.stdout_lines
EOF

# Get current timestamp for log filenames
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Run the AWS dependencies playbook and log output
echo "Running AWS dependencies playbook (${TIMESTAMP})" | tee /var/log/ansible/aws-deps-${TIMESTAMP}.log
ansible-playbook /opt/ansible/playbooks/install_aws_deps.yml 2>&1 | tee -a /var/log/ansible/aws-deps-${TIMESTAMP}.log

# Run the EBS volume mounting playbook with sudo and log output
echo "Running EBS volume mounting playbook (${TIMESTAMP})" | tee /var/log/ansible/mount-volume-${TIMESTAMP}.log
ansible-playbook /opt/ansible/playbooks/mount-data-volume.yml -b 2>&1 | tee -a /var/log/ansible/mount-volume-${TIMESTAMP}.log

# Create a symlink to the latest logs for easy access
ln -sf /var/log/ansible/aws-deps-${TIMESTAMP}.log /var/log/ansible/aws-deps-latest.log
ln -sf /var/log/ansible/mount-volume-${TIMESTAMP}.log /var/log/ansible/mount-volume-latest.log

# Write a summary
echo "Ansible playbook execution completed. Logs are available at /var/log/ansible/" | tee /var/log/ansible/summary.log
