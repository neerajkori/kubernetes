apt-get update; apt-get -y install haproxy
cat >>/etc/haproxy/haproxy.cfg << EOF
frontend kubernetes-frontend
    bind 192.168.2.200:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server kubemaster1.example.com 192.168.2.201:6443 check fall 3 rise 2
    server kubemaster2.example.com 192.168.2.202:6443 check fall 3 rise 2
    server kubemaster3.example.com 192.168.2.203:6443 check fall 3 rise 2
EOF
systemctl restart haproxy
systemctl enable haproxy
systemctl status haproxy