
# Highly Available Clusters with kubeadm

We can setup the kubernetes HA cluster  using two ways:

- With stacked control plane nodes, where etcd runs on same nodes where control plane components runs.
- With external etcd nodes, where etcd runs on separate nodes from the control plane

Within this section we will cover the second method i.e External etcd nodes.

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
# Architecture Overview - Stacked etcd
Given below is the architecture overview diagram for External etcd kubernetes ha cluster.

![License](https://kubernetes.io/images/kubeadm/kubeadm-ha-topology-external-etcd.svg)

# Environment Setup 
We will do this setup using 8 virtual machines using vagrant and OracleVirtualBox. We will do the setup on the local laptop to understand the concept behind this. 

   | Machine IP  | MAC |Hostname|Description
   | ------------- | ------------- | ----------| ------------|
   | 192.168.2.20  | Content Cell  |lb.example.com | Load Balancer
   | 192.168.2.21  | Content Cell  |kubemaster1.example.com | control-plane-1
   | 192.168.2.22  | Content Cell  |kubemaster2.example.com | control-plane-2
   | 192.168.2.23  | Content Cell  |kubemaster3.example.com | control-plane-3
   | 192.168.2.24  | Content Cell  |kubeworker1.example.com | worker-node-1
   | 192.168.2.27  | Content Cell  |etcd-7.example.com|etcd cluster node-1
   | 192.168.2.28  | Content Cell  |etcd-8.example.com| etcd cluster node-2
   | 192.168.2.29  | Content Cell  |etcd-9.example.com|etcd cluster node-3

Here we have created a seprate etcd cluster with 3 nodes as details shown above. 

### Provision etcd 3 node cluster. 
   
Provision etcd cluster nodes using below vagrant box script. 
```bash
Vagrant.configure("2") do |config|
    OS_RELEASE = 9
    (7..9).each do |i|
        config.vm.define "etcd-#{i}" do |node|
        node.vm.box = "centos/stream#{OS_RELEASE}"
        node.vm.hostname = "etcd-#{i}"
        # Calculate a unique port for each VM (2221, 2222, 2223...)
        ssh_port = 2220 + i
        node.vm.provider "virtualbox" do |vb|
            vb.name = "etcd-#{i}"
            vb.memory = "1024"
            vb.cpus = "1"
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

``` 
### Provision kubernetes cluster nodes. 
``` bash
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

``` 

# common configuration to all vms 
#### vim /etc/hosts 
```bash
192.168.2.20    lb.example.com              lb
192.168.2.21    kubemaster1.example.com     kubemaster1
192.168.2.22    kubemaster2.example.com     kubemaster2
192.168.2.23    kubemaster3.example.com     kubemaster3
192.168.2.24    kubeworker1.example.com     kubeworker1
192.168.2.27    etcd-7.example.com     etcd-7
192.168.2.28    etcd-8.example.com     etcd-8
192.168.2.29    etcd-9.example.com     etcd-9
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
    sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    setenforce 0
    systemctl disable firewalld
    sed -i '/swap/s/^/#/g' /etc/fstab
    swapoff -a


# Configuration haproxy load balancer
    yum -y install haproxy
    vim /etc/haproxy/haproxy.cfg [Append the below content to the end of the file.]

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
    systemctl start haproxy.service
    systemctl enable haproxy.service
    systemctl status haproxy.service

# Commands to run on master :   worker : etcd - cluster nodes

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
# Create etcd Cluster.
   | Machine IP  | MAC |Hostname|Description
   | ------------- | ------------- | ----------| ------------|
   | 192.168.2.27  | Content Cell  |etcd-7.example.com|etcd cluster node-1
   | 192.168.2.28  | Content Cell  |etcd-8.example.com| etcd cluster node-2
   | 192.168.2.29  | Content Cell  |etcd-9.example.com|etcd cluster node-3

### commands to run on all etcd cluster nodes.
```bash
cat << EOF > /etc/systemd/system/kubelet.service.d/kubelet.conf
# Replace "systemd" with the cgroup driver of your container runtime. The default value in the kubelet is "cgroupfs".
# Replace the value of "containerRuntimeEndpoint" for a different container runtime if needed.
#
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: false
authorization:
  mode: AlwaysAllow
cgroupDriver: systemd
address: 127.0.0.1
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
staticPodPath: /etc/kubernetes/manifests
EOF

cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/etc/systemd/system/kubelet.service.d/kubelet.conf
Restart=always
EOF
```
```bash
systemctl daemon-reload
systemctl restart kubelet
systemctl status kubelet
```
### Create configuration files for kubeadm.
Export the environment variables.

     export HOST0=192.168.2.27
     export HOST1=192.168.2.28
     export HOST2=192.168.2.29
     export NAME0="etcd-7.example.com"
     export NAME1="etcd-8.example.com"
     export NAME2="etcd-9.example.com"

Create the below script and run it.
```bash

# Update HOST0, HOST1 and HOST2 with the IPs of your hosts
export HOST0=192.168.2.27
export HOST1=192.168.2.28
export HOST2=192.168.2.29

# Update NAME0, NAME1 and NAME2 with the hostnames of your hosts
export NAME0="etcd-7.example.com"
export NAME1="etcd-8.example.com"
export NAME2="etcd-9.example.com"

# Create temp directories to store files that will end up on other hosts
mkdir -p /tmp/${HOST0}/ /tmp/${HOST1}/ /tmp/${HOST2}/

HOSTS=(${HOST0} ${HOST1} ${HOST2})
NAMES=(${NAME0} ${NAME1} ${NAME2})

for i in "${!HOSTS[@]}"; do
HOST=${HOSTS[$i]}
NAME=${NAMES[$i]}
cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
---
apiVersion: "kubeadm.k8s.io/v1beta4"
kind: InitConfiguration
nodeRegistration:
    name: ${NAME}
localAPIEndpoint:
    advertiseAddress: ${HOST}
---
apiVersion: "kubeadm.k8s.io/v1beta4"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
        - name: initial-cluster
          value: ${NAMES[0]}=https://${HOSTS[0]}:2380,${NAMES[1]}=https://${HOSTS[1]}:2380,${NAMES[2]}=https://${HOSTS[2]}:2380
        - name: initial-cluster-state
           value: ${NAMES[0]}=https://${HOSTS[0]}:2380,${NAMES[1]}=https://${HOSTS[1]}:2380,${NAMES[2]}=https://${HOSTS[2]}:2380
        - name: initial-cluster-state
          value: new
        - name: name
          value: ${NAME}
        - name: listen-peer-urls
          value: https://${HOST}:2380
        - name: listen-client-urls
          value: https://${HOST}:2379
        - name: advertise-client-urls
          value: https://${HOST}:2379
        - name: initial-advertise-peer-urls
          value: https://${HOST}:2380
```
This script will create config file for each etcd node within the /tmp/\<node ip address\> directory.
#### Create certificate authority to generate certificate for etcd service.
```bash
kubeadm init phase certs etcd-ca
```
This will creates below files.
- /etc/kubernetes/pki/etcd/ca.crt
- /etc/kubernetes/pki/etcd/ca.key

#### Create certificates for each node.
```bash
     export HOST0=192.168.2.27
     export HOST1=192.168.2.28
     export HOST2=192.168.2.29
     export NAME0="etcd-7.example.com"
     export NAME1="etcd-8.example.com"
     export NAME2="etcd-9.example.com"
```
```bash
kubeadm init phase certs etcd-server --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST2}/
# cleanup non-reusable certificates
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm init phase certs etcd-server --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST1}/
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm init phase certs etcd-server --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
# No need to move the certs because they are for HOST0

# clean up certs that should not be copied off this host
find /tmp/${HOST2} -name ca.key -type f -delete
find /tmp/${HOST1} -name ca.key -type f -delete
```
```bash
echo -n "root123" | passwd root --stdin
sed -i 's/^#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd.service
```
#### Copy certificates and kubeadm configs.
    scp -r /tmp/192.168.2.28/* root@192.168.2.28:~
    scp -r /tmp/192.168.2.29/* root@192.168.2.29:~
    
#### run below command at respective etcd node. 
```bash
root@192.168.2.27 $ kubeadm init phase etcd local --config=/tmp/192.168.2.27/kubeadmcfg.yaml
root@192.168.2.28 $ kubeadm init phase etcd local --config=$HOME/kubeadmcfg.yaml
root@192.168.2.29 $ kubeadm init phase etcd local --config=$HOME/kubeadmcfg.yaml
```
#### Check the cluster health.
```bash
  ETCDCTL_API=3 /usr/local/bin/etcdctl --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --cacert /etc/kubernetes/pki/etcd/ca.crt --endpoints https://192.168.2.27:2379 endpoint health
  ETCDCTL_API=3 /usr/local/bin/etcdctl --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --cacert /etc/kubernetes/pki/etcd/ca.crt --endpoints https://192.168.2.28:2379 endpoint health
  ETCDCTL_API=3 /usr/local/bin/etcdctl --cert /etc/kubernetes/pki/etcd/peer.crt --key /etc/kubernetes/pki/etcd/peer.key --cacert /etc/kubernetes/pki/etcd/ca.crt --endpoints https://192.168.2.29:2379 endpoint health
```

# Execute on first master node.
#### Copy the following files from any etcd node in the cluster to the first control plane node:
```bash
export CONTROL_PLANE="root@192.168.2.21"
scp /etc/kubernetes/pki/etcd/ca.crt "${CONTROL_PLANE}":
scp /etc/kubernetes/pki/apiserver-etcd-client.crt "${CONTROL_PLANE}":
scp /etc/kubernetes/pki/apiserver-etcd-client.key "${CONTROL_PLANE}":
```
#### create the kubeadm-config.yaml file.
```bash
vim kubeadm-config.yaml
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "lb.example.com:6443"
networking:
  podSubnet: 10.244.0.0/16
etcd:
  external:
    endpoints:
      - https://192.168.2.27:2379
      - https://192.168.2.28:2379
      - https://192.168.2.29:2379
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key

---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.2.21
  bindPort: 6443
```
#### Pull Images for cluster components
```bash
kubeadm config images pull
```
#### Initialize master1  cluster
```bash
kubeadm init --config kubeadm-config.yaml --upload-certs 
```
#### Install pod networking
```bash
[root@kubemaster1 ~]# kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

# Run on master2 to join cluster
#### Run to join master2 to cluster [This flag  --apiserver-advertise-address 192.168.2.22 needed only when vm has multiple network interfaces]
```bash
kubeadm join lb.example.com:6443 --token p26pge.bliqfi1wr7gesmim \
        --discovery-token-ca-cert-hash sha256:884aa35b0ce398433dc72aa24a2fc14b061d4d4de56a3836a930874885cfd138 \
        --control-plane --certificate-key 9428423142f17d9677ca9a0722a84fba13cc063a2f48adec5d8e268411cd732a --apiserver-advertise-address 192.168.2.22
```

# Run on master3 to join cluster
```bash
kubeadm join lb.example.com:6443 --token p26pge.bliqfi1wr7gesmim \
        --discovery-token-ca-cert-hash sha256:884aa35b0ce398433dc72aa24a2fc14b061d4d4de56a3836a930874885cfd138 \
        --control-plane --certificate-key 9428423142f17d9677ca9a0722a84fba13cc063a2f48adec5d8e268411cd732a --apiserver-advertise-address 192.168.2.23
```
# Add worker node to cluster
```bash
[root@kubeworker1 ~]# kubeadm join lb.example.com:6443 --token 3945wj.249jmsdglt5fvssi         --discovery-token-ca-cert-hash sha256:cd1aca9939b8bdc2839169d730d93922be00c73d442a8503ac8581a926fb3b28
```
# Now the cluster is setup completely !! 
## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with ❤ by [Neeraj](https://github.com/Neeraj)