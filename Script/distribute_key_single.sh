#!/bin/bash
IP=$1
PASSWORD="centos"
PUB_KEY_CONTENT=$(cat ~/.ssh/id_rsa.pub)
SSH_OPTS=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null" "-o" "ConnectTimeout=10")

if [ -z "$IP" ]; then
    echo "Usage: $0 <IP>"
    exit 1
fi

echo "Distributing key to $IP..."

# Root
sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" root@$IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF \"$PUB_KEY_CONTENT\" ~/.ssh/authorized_keys 2>/dev/null || echo \"$PUB_KEY_CONTENT\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh 2>/dev/null || true"
if [ $? -eq 0 ]; then echo "Root: OK"; else echo "Root: FAIL"; fi

# Ansible
sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" ansible@$IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF \"$PUB_KEY_CONTENT\" ~/.ssh/authorized_keys 2>/dev/null || echo \"$PUB_KEY_CONTENT\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh 2>/dev/null || true"
if [ $? -eq 0 ]; then echo "Ansible: OK"; else echo "Ansible: FAIL"; fi
