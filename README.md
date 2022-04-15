sudo kubeadm config images pull
sudo kubeadm config print init-defaults
sudo kubeadm init --config /etc/kubeadm/config.yaml --v=10

sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps -a
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock logs CONTAINERID
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps -a | grep kube | grep -v pause

container-runtime=remote   --container-runtime-endpoint=<path>    --cgroup-driver  --cri-socket

sudo grep -i -n --color error /var/log/cloud-init.log
sudo grep -i -n --color warn /var/log/cloud-init.log
sudo grep -i -n --color error /var/log/cloud-init-output.log
sudo grep -i -n --color warn /var/log/cloud-init-output.log
sudo cat -n /var/log/cloud-init.log
sudo cat -n /var/log/cloud-init-output.log

sudo cat /etc/cni/net.d/10-azure.conflist
sudo cat /var/log/azure-vnet.log
sudo ls -la /opt/cni/bin

sudo systemctl status containerd
sudo journalctl -xeu containerd

sudo systemctl status kubelet
sudo journalctl -xeu kubelet

kubectl -n kube-system get deployments

#Check etcd. Run this from master.
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

#Check containerd
crictl info

#Verify workers are bootstapped
kubectl get nodes

kubectl -n kube-system exec -it etcd-<Tab> -- sh

#Troubleshoot coredns
dig @<pod ip address> kubernetes.default.svc.cluster.local +noall +answer

##MANIFESTS
/etc/kubernetes/manifests/

Generated kubelet config yaml is at: /var/lib/kubelet/config.yaml
Generated kubelet flags is at: /var/lib/kubelet/kubeadm-flags.env


cat /var/lib/cloud/instance user-data.txt
cloud-init devel schema --config-file /var/lib/cloud/instance user-data.txt
cloud-init devel schema --config-file /mnt/c/Users/brian/git/cloudruler/infrastructure/sandbox/user-data-master-azure.yml

kubeadm token generate
kubeadm certs certificate-key


sudo cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo cat /etc/kubernetes/admin.conf
sudo cat /var/lib/kubelet/config.yaml

/var/lib/etcd


Create and use a Discovery Token CA Cert Hash created from the cp to ensure the node joins the cluster in a secure
manner. Run this on the cp node or wherever you have a copy of the CA file. You will get a long string as output. Also
note that a copy and paste from a PDF sometimes has issues with the caret (ˆ) and the single quote (’) found at the end
of the command.
student@cp:˜$ openssl x509 -pubkey \
-in /etc/kubernetes/pki/ca.crt | openssl rsa \
-pubin -outform der 2>/dev/null | openssl dgst \
-sha256 -hex | sed 's/ˆ.* //'


  client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
  client-key: /var/lib/kubelet/pki/kubelet-client-current.pem


https://k8s.cloudruler.io:6443/api/v1/pods?fieldSelector=spec.nodeName%3Dvm-k8s-master000000&limit=500&resourceVersion=0
https://k8s.cloudruler.io:6443/api/v1/services?limit=500&resourceVersion=0
https://k8s.cloudruler.io:6443/api/v1/namespaces/default/events

kubelet "times out" trying to register the node with the API server
HTTP get and post to API server fails from kubelet
i can curl API server from the node
try setting configuration values
try connecting kubectl to the API server


sudo iptables -t nat -A POSTROUTING -m iprange ! --dst-range 168.63.129.16 -m addrtype ! --dst-type local ! -d 10.1.0.0/16 -j MASQUERADE

--cloud-provider=azure

#Verify control plane is bootstrapped (run this from a master)
#This is deprecated and show unhealthy
kubectl get componentstatuses

###########RUN BOOTSTRAPPING OF WORKER NODES

controller-manager "http://127.0.0.1:10252/healthz" connection refused

/var/lib/kubelet/config.yaml


dig is the gold standard for debugging DNS
dig -p 1053 @localhost +noall +answer <name> <type>

wget https://training.linuxfoundation.org/cm/LFS258/LFS258_V2022-03-22_SOLUTIONS.tar.xz --user=LFtraining --password=Penguin2014
tar -xvf LFS258_V2022-03-22_SOLUTIONS.tar.xz




######## discovery-token-ca-cert-hash
If you don't have the value of --discovery-token-ca-cert-hash, you can get it by running the following command chain on the control-plane node:

openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
   ###

####
These connections terminate at the kubelet's HTTPS endpoint. By default, the apiserver does not verify the kubelet's serving certificate, which makes the connection subject to man-in-the-middle attacks and unsafe to run over untrusted and/or public networks.

To verify this connection, use the --kubelet-certificate-authority flag to provide the apiserver with a root certificate bundle to use to verify the kubelet's serving certificate.
========================

sudo su
CRIO_VERSION=1.23
CRIO_OS_VERSION=xUbuntu_20.04
ADMIN_USERNAME=cloudruleradmin
modprobe overlay
modprobe br_netfilter
sysctl --system
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$CRIO_OS_VERSION/ /" | tee -a /etc/apt/sources.list.d/cri-0.list
curl -L http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$CRIO_OS_VERSION/Release.key | apt-key add -
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$CRIO_OS_VERSION/ /" | tee -a /etc/apt/sources.list.d/libcontainers.list
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$CRIO_OS_VERSION/Release.key | apt-key add -
echo deb https://apt.kubernetes.io/ kubernetes-xenial main | tee -a /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get update

apt-get install -y cri-o cri-o-runc
systemctl daemon-reload
systemctl enable crio
systemctl start crio
apt-get install -y kubelet=1.22.1-00 kubeadm=1.22.1-00 kubectl=1.22.1-00
apt-mark hold kubelet kubeadm kubectl

#If this is a master node, grab the certs we need
mkdir -p /etc/kubernetes/pki/etcd
cp /var/lib/waagent/${certificates["ca-kubernetes"]}.crt /etc/kubernetes/pki/ca.crt
cp /var/lib/waagent/${certificates["ca-kubernetes"]}.prv /etc/kubernetes/pki/ca.key
cp /var/lib/waagent/${certificates["ca-etcd"]}.crt /etc/kubernetes/pki/etcd/ca.crt
cp /var/lib/waagent/${certificates["ca-etcd"]}.prv /etc/kubernetes/pki/etcd/ca.key
cp /var/lib/waagent/${certificates["ca-kubernetes-front-proxy"]}.crt /etc/kubernetes/pki/front-proxy-ca.crt
cp /var/lib/waagent/${certificates["ca-kubernetes-front-proxy"]}.prv /etc/kubernetes/pki/front-proxy-ca.key

#Initialize the cluster
kubeadm init --config /etc/kubeadm/config.yaml --upload-certs
mkdir -p /home/$ADMIN_USERNAME/.kube
cp /etc/kubernetes/admin.conf /home/$ADMIN_USERNAME/.kube/config
chown $ADMIN_USERNAME:$ADMIN_USERNAME /home/$ADMIN_USERNAME/.kube/config
kubectl apply -f /tmp/calico.yaml


===========================

kubectl -n kube-system exec -it etcd-vm-k8s-master-0 -- sh \ #Same as before
-c "ETCDCTL_API=3 \ #Version to use
ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt \ #Pass the certificate authority
ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt \ #Pass the peer cert and key
ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key \
etcdctl endpoint health" #The command to test the endpoint



kubectl -n kube-system exec -it etcd-vm-k8s-master-0 -- sh -c "ETCDCTL_API=3 ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key etcdctl endpoint health"

kubectl -n kube-system exec -it etcd-vm-k8s-master-0 -- sh -c "ETCDCTL_API=3 ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key etcdctl --endpoints=https://127.0.0.1:2379 member list"

kubectl -n kube-system exec -it etcd-vm-k8s-master-0 -- sh -c "ETCDCTL_API=3 ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key etcdctl --endpoints=https://127.0.0.1:2379 member list -w table"

kubectl -n kube-system exec -it etcd-vm-k8s-master-0 -- sh -c "ETCDCTL_API=3 ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key etcdctl --endpoints=https://127.0.0.1:2379 snapshot save /var/lib/etcd/snapshot.db"

