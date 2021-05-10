#!/usr/bin/bash


set -xe

if [$1 -eq 'centos']
then
    echo "Running Script of Centos Machine."

    echo "[1. Create file to load containerd modules during system statup. ]"
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter

    echo "[2. Enable Systemctl parameter for kubernetes for system startup.]"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl --system

    echo "[3. Installing Containerd as a container runtime engine.]"
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum -y install containerd.io
    containerd config default | sudo tee /etc/containerd/config.toml
    sed -i '/\[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options\]/a    \\t \t SystemdCgroup\ \=\ true' /etc/containerd/config.toml


    echo "[4. Starting & Enabling containerd service on the machine.]"
    systemctl restart containerd
    systemctl enable containerd
    systemctl status containerd

    echo "[5. Installing kubeadm binary on the woker node. ]"

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sed -i '/swap/s/^/#/g' /etc/fstab
    swapoff -a
    echo "[6. Installing kubelet kubeadm kubectl binary on the woker node.]"
    yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    # Installing crictl
    RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
    DOWNLOAD_DIR=/usr/bin
    CRICTL_VERSION=$RELEASE
    curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
    systemctl enable --now kubelet
    kubectl completion bash >/etc/bash_completion.d/kubectl
    source /etc/bash_completion.d/kubectl
    kubeadm completion bash > /etc/bash_completion.d/kubeadm
    source /etc/bash_completion.d/kubeadm
    sshpass -p srvlogin1234  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@192.168.2.201 kubeadm token create --print-join-command  | bash
else
    echo "Running Script of Debian Machine."

    echo "[1. Create file to load containerd modules during system statup. ]"
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter

    echo "[2. Enable Systemctl parameter for kubernetes for system startup.]"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl --system

    echo "[3. Installing Containerd as a container runtime engine.]"
    apt-get update ; apt-get remove docker  docker.io containerd runc
    apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg  --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get -y install containerd.io


    containerd config default | sudo tee /etc/containerd/config.toml
    sed -i '/\[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options\]/a    \\t \t SystemdCgroup\ \=\ true' /etc/containerd/config.toml


    echo "[4. Starting & Enabling containerd service on the machine.]"
    systemctl restart containerd
    systemctl enable containerd
    systemctl status containerd

    echo "[5. Installing kubeadm binary on the woker node. ]"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    sysctl --system

    apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    swapoff -a
    systemctl enable --now kubelet

    kubectl completion bash >/usr/share/bash-completion/kubectl
    source /usr/share/bash-completion/kubectl
    kubeadm completion bash > /usr/share/bash-completion/kubeadm
    source /usr/share/bash-completion/kubeadm
    sshpass -p srvlogin123  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@192.168.2.201 kubeadm token create --print-join-command  | bash
fi