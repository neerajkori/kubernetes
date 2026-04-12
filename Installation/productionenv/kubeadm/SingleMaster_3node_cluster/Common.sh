#!/usr/bin/bash

set -xe 

# Installing common packages for the entire cluster.
echo "[1.  Installing common packages for the entire cluster ]"
yum -y install net-tools vim sshpass

# Enabling ssh login for root user account.
echo "[2. Enable ssh root access for all the machines. ]"
echo -n "root123" | passwd root --stdin
sed -i 's/^#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd.service

echo "[3. Adding host entries.]"
cat >>/etc/hosts<<EOF
192.168.2.200   kubemaster.example.com     kubemaster
192.168.2.21   kubeworker1.example.com    kubeworker1
192.168.2.22   kubeworker2.example.com    kubeworker2
EOF



