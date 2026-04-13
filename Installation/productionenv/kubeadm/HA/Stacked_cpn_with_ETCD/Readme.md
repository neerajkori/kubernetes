
# Highly Available Clusters with kubeadm

We can setup the kubernetes HA cluster  using two ways:

- With stacked control plane nodes, where etcd runs on same nodes where control plane components runs.
- With external etcd nodes, where etcd runs on separate nodes from the control plane

Within this section we will cover the first methos i.e Staked control plan nodes - [Stacked-cpn]

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
# Architecture Overview - Stacked etcd
Given below is the architecture overview diagram for Stacked etcd kubernetes ha cluster.

![License](https://kubernetes.io/images/kubeadm/kubeadm-ha-topology-stacked-etcd.svg)

# Environment Setup 
We will do this setup using 5 virtual machines using vagrant and OracleVirtualBox. We will do the setup on the local laptop to understand the concept behind this. 
- Machine Configuration.
     - 192.168.2.20    Ha-proxy load balancer                      
     - 192.168.2.21    kubemaster1
     - 192.168.2.22    kubemaster2
     - 192.168.2.23    kubemaster3
     - 192.168.2.24    kubeworker1
   
    
Provision all the vagrant boxes/machine using below vagrant file. This will provision 5 VMS.

        Vagrant.configure("2") do |config|
        OS_RELEASE = 9
        (0..4).each do |i|
            config.vm.define "kube-#{i}" do |node|
            node.vm.box = "centos/stream#{OS_RELEASE}"
            node.vm.hostname = "kube-#{i}"
            # Calculate a unique port for each VM (2221, 2222, 2223...)
            ssh_port = 2220 + i
            node.vm.provider "virtualbox" do |vb|
                vb.name = "kube-#{i}"
                vb.memory = "2048"
                vb.cpus = "2"
                # NIC 1: Your Host-Only Adapter (eth0)
                vb.customize ["modifyvm", :id, "--nic1", "hostonly", "--hostonlyadapter1", "VirtualBox Host-Only Ethernet Adapter #2"]
                # NIC 2: NAT for SSH (eth1)
                vb.customize ["modifyvm", :id, "--nic2", "nat"]
                # Map the UNIQUE host port to guest port 22
                vb.customize ["modifyvm", :id, "--natpf2", "ssh,tcp,127.0.0.1,#{ssh_port},,22"]
            end
            # Tell Vagrant to use the unique port for THIS node
            node.ssh.host = "127.0.0.1"
            node.ssh.port = ssh_port
            node.vm.provision "shell", inline: <<-SHELL
                nmcli con mod "System eth0" ipv4.addresses 192.168.2.2#{i}/24 ipv4.method manual
                nmcli con up "System eth0"
            SHELL
            end
        end
    end


# common configuration to all vms 
```bash
vim /etc/hosts 

192.168.2.20    lb.example.com              lb
192.168.2.21    kubemaster1.example.com     kubemaster1
192.168.2.22    kubemaster2.example.com     kubemaster2
192.168.2.23    kubemaster3.example.com     kubemaster3
192.168.2.24    kubeworker1.example.com     kubeworker1
```
#### Installing basic utilities on all the machine. 
```bash
yum -y install net-tools sshpass vim 
```
#### Set hostname on each machine
```bash

192.168.2.20   - # hostnamectl set-hostname lb.example.com                     # exec bash            
192.168.2.21   - # hostnamectl set-hostname kubemaster1.example.com   # exec bash    
192.168.2.22   - # hostnamectl set-hostname kubemaster2.example.com  # exec bash     
192.168.2.23   - # hostnamectl set-hostname kubemaster3.example.com  # exec bash     
192.168.2.24   - # hostnamectl set-hostname kubeworker1.example.com  # exec bash
```

####  Disable se-linux and swap on all the machines. 
    # sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    # setenforce 0
    # systemctl disable firewalld
    # sed -i '/swap/s/^/#/g' /etc/fstab
    # swapoff -a


# Configuration haproxy load balancer
    # yum -y install haproxy
    # vim /etc/haproxy/haproxy.cfg [Append the below content to the end of the file.]

        frontend kubernetes-frontend
            bind 192.168.2.20:6443
            mode tcp
            option tcplog
            default_backend kubernetes-backend

        backend kubernetes-backend
            mode tcp
            option tcp-check
            balance roundrobin
            server kubemaster1.example.com 192.168.2.21:6443 check fall 3 rise 2
            server kubemaster2.example.com 192.168.2.22:6443 check fall 3 rise 2
            server kubemaster3.example.com 192.168.2.23:6443 check fall 3 rise 2
#### Restart and enable the loadbalancer service
    # systemctl start haproxy.service
    # systemctl enable haproxy.service
    # systemctl status haproxy.service

# Commands to run on all the kubernetes nodes[master + worker nodes].

#### Load containerd modules during system statup.
```bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter
```
#### Enable iptables and net forwarding
```bash
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
```

#### Installing Containerd as a container runtime engine
```bash
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum -y install containerd.io
    containerd config default | sudo tee /etc/containerd/config.toml
    sed -i '/\[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options\]/a    \\t \t SystemdCgroup\ \=\ true' /etc/containerd/config.toml
```
#### Starting & Enabling containerd service on the machine
    systemctl restart containerd
    systemctl enable containerd
    systemctl status containerd

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    sysctl --system
```
#### Enable repository
```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.35/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.35/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```
#### Installing kubeadm, kubelet, kubeproxy ,crictl
```bash
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
# RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
RELEASE="v1.35.0"
DOWNLOAD_DIR=/usr/bin
CRICTL_VERSION=$RELEASE
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
#curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.21.0/crictl-v1.21.0-linux-amd64.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
systemctl enable --now kubelet
kubectl completion bash >/etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubeadm
```
# Execute on first master node.
#### Pull Images for cluster components
```bash
kubeadm config images pull
```
#### Initialize cluster
```bash
kubeadm init --upload-certs --control-plane-endpoint "lb.example.com:6443" --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.2.21
```
#### Install pod networking
```bash
[root@kubemaster1 ~]# kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

# Run on master2 to join cluster
#### Run to join master2 to cluster [This flag  --apiserver-advertise-address 192.168.2.22 needed only when vm has multiple network interfaces]
```bash
[root@kubemaster2 ~]# kubeadm join lb.example.com:6443 --token 3945wj.249jmsdglt5fvssi         --discovery-token-ca-cert-hash sha256:cd1aca9939b8bdc2839169d730d93922be00c73d442a8503ac8581a926fb3b28         --control-plane --certificate-key 925df49a84ddcccba207937909f2cd0612319a67ad75dca24c20d19713d01b3c        --apiserver-advertise-address 192.168.2.22
```

# Run on master3 to join cluster
```bash
[root@kubemaster3 ~]# kubeadm join lb.example.com:6443 --token 3945wj.249jmsdglt5fvssi         --discovery-token-ca-cert-hash sha256:cd1aca9939b8bdc2839169d730d93922be00c73d442a8503ac8581a926fb3b28         --control-plane --certificate-key 925df49a84ddcccba207937909f2cd0612319a67ad75dca24c20d19713d01b3c        --apiserver-advertise-address 192.168.2.23
```
# Add worker node to cluster
```bash
[root@kubeworker1 ~]# kubeadm join lb.example.com:6443 --token 3945wj.249jmsdglt5fvssi         --discovery-token-ca-cert-hash sha256:cd1aca9939b8bdc2839169d730d93922be00c73d442a8503ac8581a926fb3b28
```
## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with ❤ by [Neeraj](https://github.com/Neeraj)