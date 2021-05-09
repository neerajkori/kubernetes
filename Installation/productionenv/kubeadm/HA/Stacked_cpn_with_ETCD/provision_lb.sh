#!/usr/bin/bash
set -xe

echo "----------------"
echo $1
echo "----------------"

if [ "$1" = "centos" ]; then
    yum -y update ; yum -y install haproxy
    setsebool -P haproxy_connect_any=1
else
    apt-get update; apt-get -y install haproxy
fi

cat >>/etc/haproxy/haproxy.cfg << EOF
frontend kubernetes-frontend
    bind 192.168.1.200:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server kubemaster1.example.com 192.168.1.201:6443 check fall 3 rise 2
    server kubemaster2.example.com 192.168.1.202:6443 check fall 3 rise 2
    server kubemaster3.example.com 192.168.1.203:6443 check fall 3 rise 2
EOF

systemctl restart haproxy
systemctl enable haproxy
systemctl status haproxy