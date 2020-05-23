# Configuring kubectl for Remote Access

In this lab you will generate a kubeconfig file for the `kubectl` command line utility based on the `admin` user credentials.

> Run the commands in this lab from the same directory used to generate the admin client certificates.

## The Admin Kubernetes Configuration File

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

### Setting up an SSH tunnel:
```bash
ssh-agent bash 
ssh-add id_rsa
# Listen on port 6443 on the host OS and forward the traffic to the load balancer port 6443
ssh -L 6443:localhost:6443 vagrant@192.168.13.11
```
> This SSH session should be left open, the rest of the commands will be executed from the host 

Generate a kubeconfig file suitable for authenticating as the `admin` user:

```
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://localhost:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}
```

## Verification

Check the health of the remote Kubernetes cluster:

```
kubectl get componentstatuses
```

> output

```
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-0               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}   
```

List the nodes in the remote Kubernetes cluster:

```
kubectl get nodes
```

> output

```
NAME         STATUS     ROLES    AGE   VERSION
node-1.com   NotReady   <none>   21h   v1.15.3
node-2.com   NotReady   <none>   21h   v1.15.3

```

Next: [Provisioning Pod Network Routes](11-pod-network-routes.md)
