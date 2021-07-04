#!/usr/bin/bash

set -xe

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

echo "[5. Installing kubeadm binary on the master server. ]"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

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

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
# Installing crictl
# RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
RELEASE="v1.21.0"
DOWNLOAD_DIR=/usr/bin
CRICTL_VERSION=$RELEASE
# curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.21.0/crictl-v1.21.0-linux-amd64.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
systemctl enable --now kubelet
kubectl completion bash >/etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubeadm


echo "[6. Installing kubernetes cluster on the master server. ]"
kubeadm config images pull
kubeadm init  --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.2.200

echo "[7. Deploy Calico network]"
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml >/dev/null 2>&1

echo "[8. Configuring kubectl]"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config















