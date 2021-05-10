#!/usr/bin/bash

set -xe 
if [$1 -eq 'centos']
then
    echo "Running Script of Centos Machine."

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
    sed -i '/kube/d' /etc/hosts
cat >>/etc/hosts<<EOF
192.168.2.200   kubemaster.example.com     kubemaster
192.168.2.20   kubeworker1.example.com    kubeworker1
192.168.2.21   kubeworker2.example.com    kubeworker2
EOF
else
    echo "Running Script on the Debian Machine."
    # Installing common packages for the entire cluster.
    echo "[1.  Installing common packages for the entire cluster ]"
    apt-get update ;apt-get -y install vim net-tools sshpass

    # Enabling ssh login for root user account.
    echo "[2. Enable ssh root access for all the machines. ]"
    echo -e "srvlogin123\nsrvlogin123" | passwd root
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    systemctl restart sshd.service

    echo "[3. Adding host entries.]"
    sed -i '/kube/d' /etc/hosts
    sed -i '/ETCD/d' /etc/hosts
    sed -i '/Proxy/d' /etc/hosts
    sed -i '/lb/d' /etc/hosts

cat >>/etc/hosts<<EOF
192.168.2.200   lb.example.com             lb
192.168.2.201   kubemaster1.example.com     kubemaster1
192.168.2.202   kubemaster2.example.com     kubemaster2
192.168.2.203   kubemaster3.example.com     kubemaster3
192.168.2.21    kubeworker1.example.com     kubeworker1
192.168.2.101   ETCD1.example.com     ETCD1
192.168.2.102   ETCD2.example.com     ETCD2
192.168.2.103   ETCD3.example.com     ETCD3
EOF

fi







