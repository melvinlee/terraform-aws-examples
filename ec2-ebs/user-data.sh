#!/bin/bash

# Update system packages
yum update -y

# Install Python pip
yum install -y python3-pip

# Install Ansible
pip3 install ansible

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

# Run the playbook
ansible-playbook /opt/ansible/playbooks/install_aws_deps.yml
