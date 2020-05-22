### What is the Kubernetes Control Plane:
* Collection of services that controls the kubernetes cluster (must be installed on all the master nodes)

* It's responsible for making decisions about the cluster 
	* Scheduling
	* detect & repond to cluster events i.e starting a new pod when the `replication-controller` replicas field is unsatisfied (auto-scaling)

### What are the components of the Kubernetes Control Plane:
1. **kube-apiserver**: allows interaction with the cluster, this is the `interface` to the control plane
2. **etcd**: distributed datastore for the kubernetes cluster
3. **kube-scheduler**: Finds worker nodes that are available for running pods
4. **kube-controller-manager**: Collection of controllers (services that does other set of functionalities)
5. **cloud-controller-manager**: Responsible for dealing with the cloud providers (GCP, amazon, azuer etc ..)

# Bootstrapping the Kubernetes Control Plane

In this lab you will bootstrap the Kubernetes control plane across 2 vagrant machines and configure it for high availability.
You will also create an external load balancer that exposes the Kubernetes API Servers to remote clients. The following components will be installed on each node: Kubernetes API Server, Scheduler, and Controller Manager.

![apiserver-loadbalancer diagram]()

## Provision the Kubernetes Control Plane

Create the Kubernetes configuration directory:

```bash
# executed on both master-1 and master-2

sudo mkdir -p /etc/kubernetes/config
```

### Download and Install the Kubernetes Controller Binaries

Download the official Kubernetes release binaries:

> This command will take time so be patient

```bash
# executed on both master-1 and master-2

wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"
```

Install the Kubernetes binaries:

```bash
# on both master-1 and master-2

{
  binaries='kube-apiserver kube-controller-manager kube-scheduler kubectl'
  for binary in $binaries; do
    chmod +x $binary && sudo mv $binary /usr/local/bin
  done
}
```

### Configure the Kubernetes API Server

```bash
# on both master-1 and master-2

{
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
}
```

The machine's internal IP address will be used to advertise the API Server to members of the cluster, here we set a temporary environment variable holding the IP address:

```bash
# only on master-1
INTERNAL_IP=192.168.11.11 && echo $INTERNAL_IP

# only on master-2
INTERNAL_IP=192.168.11.12 && echo $INTERNAL_IP
```

set up a static IP environment variable for both masters on each machine:
```bash
# master-1 (on both machines)
MASTER1_IP=192.168.11.11 && echo $MASTER1_IP

# master-2 (on both machines)
MASTER2_IP=192.168.11.12 && echo $MASTER2_IP
```

Create the `kube-apiserver.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://$MASTER1_IP:2379,https://$MASTER2_IP:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2 \\
  --kubelet-preferred-address-types=InternalIP,InternalDNS,Hostname,ExternalIP,ExternalDNS
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Controller Manager

Copy the `kube-controller-manager` kubeconfig into place:

```bash
sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

Create the `kube-controller-manager.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Scheduler

Move the `kube-scheduler` kubeconfig into place:

```bash
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/
```

Create the `kube-scheduler.yaml` configuration file:

```
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
```

Create the `kube-scheduler.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the Controller Services

```bash
sudo systemctl daemon-reload && sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler --now 

# verify that services are enabled and started
sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler
```

> Allow up to 10 seconds for the Kubernetes API Server to fully initialize.

Verify by querying the kubernetes control plane:
```bash
kubectl get componentstatuses --kubeconfig admin.kubeconfig 
```

Expected output:
```
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-1               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}  
```
---

### Enable HTTP Health Checks:
The load balancer needs to perform HTTP health checks against the kubernetes api in order to get the health status of the api nodes so that we avoid sending traffic to any of the unhealthy nodes

check the health endpoint
```bash
# on both master-1 and master-2
curl -k https://localhost:6443/healthz #expected response is: ok
```

The goal is to create a proxy to allow this check to happen even over HTTP (if the same command is executed again but with http instead of https it will fail).

> The `/healthz` API server endpoint does not require authentication by default.


Install NGINX web server to handle HTTP health checks:

```bash
sudo apt-get update && sudo apt-get install -y nginx
```

Create a configuration file for our proxy:

```
cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
```

```bash
# config files are always placed in /etc/nginx/sites-available
sudo mv kubernetes.default.svc.cluster.local \
  /etc/nginx/sites-available/kubernetes.default.svc.cluster.local

# create a symlink to that file that will activate the previous config file
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
```

```bash
sudo systemctl restart nginx && sudo systemctl enable nginx
```

### Verification

Test the nginx HTTP health check proxy:

```bash
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz
```

Expected response:
```
HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Sat, 14 Sep 2019 18:34:11 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive
X-Content-Type-Options: nosniff

ok
```

---

### What is [RBAC authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/):
RBAC stands for Rule Based Access Control and is a method of manaing access to computers and network resources based on specific roles 

## RBAC for Kubelet Authorization

In this section you will configure RBAC permissions to allow the Kubernetes API Server to access the Kubelet API on each worker node. Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

> This tutorial sets the Kubelet `--authorization-mode` flag to `Webhook`. Webhook mode uses the [SubjectAccessReview](https://kubernetes.io/docs/admin/authorization/#checking-api-access) API to determine authorization.

The commands in this section will affect the entire cluster and only need to be run once from one of the master nodes.

Create the `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/admin/authorization/rbac/#role-and-clusterrole) with permissions to access the Kubelet API and perform most common tasks associated with managing pods:

```
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

Expected output
```
clusterrole.rbac.authorization.k8s.io/system:kube-apiserver-to-kubelet created
```

The Kubernetes API Server authenticates to the Kubelet as the `kubernetes` user using the client certificate as defined by the `--kubelet-client-certificate` flag.

Bind (assign) the `system:kube-apiserver-to-kubelet` ClusterRole to the `kubernetes` user:

```
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## The Kubernetes Frontend Load Balancer

In this section you will provision an external load balancer to front the Kubernetes API Servers. The `kubernetes-the-hard-way` static IP address will be attached to the resulting load balancer.

Install nginx on the load-balancer machine:
```bash
sudo apt-get update && sudo apt-get -y install nginx

# enable and start nginx 
sudo systemctl enable nginx --now

sudo mkdir -p /etc/nginx/tcpconf.d
```

Modify the nginx config file:
```bash
sudo vi /etc/nginx/nginx.conf

# add to the last line in the file 
include /etc/nginx/tcpconf.d/*;

# set temporary enviornment variables matching IP address of the master nodes
MASTER1_IP=192.168.11.11 && echo $MASTER1_IP
MASTER2_IP=192.168.11.12 && echo $MASTER2_IP
```

Create the configuration file at the newly created directory:
```bash
cat << EOF | sudo tee /etc/nginx/tcpconf.d/kubernetes.conf
stream {
  upstream kubernetes {
    server $NODE1_IP:6443;
    server $NODE2_IP:6443;
  }

  server {
    listen 6443;
    listen 443;
    proxy_pass kubernetes;
  }
}
EOF
```
> kubernetes API server always listens to port 6443

Reload nginx configuration
```bash
sudo nginx -s reload
```

Test the configuration:
```bash
curl -k https://localhost:6443/version
```

Expected output:
```
{
  "major": "1",
  "minor": "15",
  "gitVersion": "v1.15.3",
  "gitCommit": "2d3c76f9091b6bec110a5e63777c332469e0cba2",
  "gitTreeState": "clean",
  "buildDate": "2019-08-19T11:05:50Z",
  "goVersion": "go1.12.9",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```

Next: [Bootstrapping the Kubernetes Worker Nodes](09-bootstrapping-kubernetes-workers.md)
