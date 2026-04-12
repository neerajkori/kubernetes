# kubernetes

Here with in this part we are installing Kubernetes cluster version 1.35 on centos/stream9 operating system. 

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Table of Contents

- [Installation](#Installation)
    - [Vagrant](#vagrant)
        - [Prerequisite]()
            -
            Vagrant and Oracle VirtualBox Must be installed on the system.
        
    
            Run the below commands within terminal to provision k8s cluster using vagrant
            ```bash
            # git clone https://github.com/Neeraj/kubernetes.git
            # cd kubernetes\Installation\productionenv\kubeadm\SingleMaster_3node_cluster
            # vagrant up 
            ```
    - [Manual](#manual)
        # Steps to run on all nodes.
        1.	Verify the MAC address and product_uuid are unique for every node (run on all the nodes) to verify mac address must be unique.
        ```bash
		# cat /sys/class/dmi/id/product_uuid & # ifconfig -a
        ```
         2.	check for the open ports on all the nodes.
         ```bash
		# nc 127.0.0.1 6443 -zv -w 2
        ```
        3.	Disable Swap configuration.
         ```bash
        # open /etc/fstab and # hash the swap entry and restart the machine.
        ```
        4.	configure hosts on all machines and make the below entries.
         ```bash
		# vim /etc/hosts
			192.168.56.110   kubemaster.example.com     kubemaster
			192.168.56.111   kubeworker1.example.com    kubeworker1
			192.168.56.112   kubeworker2.example.com    kubeworker2
        ```
        5. 	Installing kubeadm, kubelet and kubectl on all machines.
         ```bash
		# apt-get update
  		# apt-get install -y apt-transport-https ca-certificates curl gpg
  		# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  		# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

		# apt-get update
  		# apt-get install -y kubelet kubeadm kubectl
  		# apt-mark hold kubelet kubeadm kubectl
        ```
        
        6. Ports and Protocols required to be opened.[Information]
        ```bash
        1. Control plane
            TCP	Inbound	6443	Kubernetes API server	All
            TCP	Inbound	2379-2380	etcd server client API	kube-apiserver, etcd
            TCP	Inbound	10250	Kubelet API	Self, Control plane
            TCP	Inbound	10259	kube-scheduler	Self
            TCP	Inbound	10257	kube-controller-manager	Self
        2. Worker node
            TCP	Inbound	10250	Kubelet API	Self, Control plane
            TCP	Inbound	10256	kube-proxy	Self, Load balancers
            TCP	Inbound	30000-32767	NodePort Services†	All
            UDP	Inbound	30000-32767	NodePort Services†	All
        ```

        7. confugure cgroups.
        ```bash
        1.	# containerd config default | sudo tee /etc/containerd/config.toml
            # sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
            # systemctl restart containerd
        ```
        # Steps to run on all master node.
        Installing cluster with kubeadm
        ```bash
            1. 	# kubeadm config images pull
                # kubeadm init  --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.56.110
        ```
        ## Below is the output of the command.
                Your Kubernetes control-plane has initialized successfully!

                To start using your cluster, you need to run the following as a regular user:

                mkdir -p $HOME/.kube
                sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
                sudo chown $(id -u):$(id -g) $HOME/.kube/config

                Alternatively, if you are the root user, you can run:

                export KUBECONFIG=/etc/kubernetes/admin.conf

                You should now deploy a pod network to the cluster.
                Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
                https://kubernetes.io/docs/concepts/cluster-administration/addons/

                Then you can join any number of worker nodes by running the following on each as root:

                kubeadm join 192.168.56.110:6443 --token 4ham6h.g31ilfsdldu0re18 \
                        --discovery-token-ca-cert-hash sha256:87c72e5ee4f7a09b43420ef512bc3b1b3f62bc07e53eb76588a9acc6c73d44af
        ```bash
            2. 	# kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        ```
        ```bash
            3. #kubectl get pods -n kube-system
                NAME                                             READY   STATUS    RESTARTS        AGE
                coredns-7d764666f9-b5k6h                         0/1     Pending   0               2m33s
                coredns-7d764666f9-rl6fb                         0/1     Pending   0               2m32s
                etcd-kubemaster.example.com                      1/1     Running   0               3m41s
                kube-apiserver-kubemaster.example.com            1/1     Running   0               3m41s
                kube-controller-manager-kubemaster.example.com   1/1     Running   1 (3m13s ago)   3m40s
                kube-proxy-vzf25                                 1/1     Running   0               2m34s
                kube-scheduler-kubemaster.example.com            1/1     Running   1               3m42s
        ```bash
    # Steps to run on all worker node.
            1. #kubeadm join 192.168.56.110:6443 --token 4ham6h.g31ilfsdldu0re18 \
              --discovery-token-ca-cert-hash sha256:87c72e5ee4f7a09b43420ef512bc3b1b3f62bc07e53eb76588a9acc6c73d44af
## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with ❤ by [Neeraj](https://github.com/Neeraj)