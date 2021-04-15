#!/usr/bin/bash

set -xe 

# Installing common packages for the entire cluster.
echo "[1.  Installing common packages for the entire cluster ]"
yum -y install net-tools vim epel-release
yum  makecache ; yum install sshpass -y

# Enabling ssh login for root user account.
echo "[2. Enable ssh root access for all the machines. ]"
echo -n "srvlogin1234" | passwd root --stdin
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd.service

echo "[3. Adding host entries.]"
cat >>/etc/hosts<<EOF
192.168.2.200   kubemaster.example.com     kubemaster
192.168.2.20   kubeworker1.example.com    kubeworker1
192.168.2.21   kubeworker2.example.com    kubeworker2
EOF



