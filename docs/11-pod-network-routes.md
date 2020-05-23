# Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network [routes](https://cloud.google.com/compute/docs/vpc/routes).

In this lab you will create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address.

> There are [other ways](https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this) to implement the Kubernetes networking model.


Turn on IP forwarding on both worker nodes:
```bash
# enable port forwarding in the current session
sudo sysctl net.ipv4.conf.all.forwarding=1

# permanently enable the forwarding
sudo echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf
```

### Installing Weavenet:
```bash
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=10.200.0.0/16"
```

Expected Output on the host:
```
serviceaccount/weave-net created
clusterrole.rbac.authorization.k8s.io/weave-net created
clusterrolebinding.rbac.authorization.k8s.io/weave-net created
role.rbac.authorization.k8s.io/weave-net created
rolebinding.rbac.authorization.k8s.io/weave-net created
daemonset.apps/weave-net created
```

Verify:

```bash
# executed on host
kubectl get pods -n kube-system
```

Expected output:
```
NAME              READY   STATUS    RESTARTS   AGE
weave-net-gqzvj   2/2     Running   0          118s
weave-net-hwx57   2/2     Running   0          118s
```

### Test connectivity between pods:
Set up 2 test pods running NGINX:
```yaml
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      run: nginx
  replicas: 2
  template:
    metadata:
      labels:
        run: nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
EOF
```

check pods status:
```
kubectl get po
```

Expected output:
```
NAME                     READY   STATUS              RESTARTS   AGE
nginx-5b8c4fbff7-cm5d6   0/1     ContainerCreating   0          53s
nginx-5b8c4fbff7-jxqh8   0/1     ContainerCreating   0          53s
```


Create a service to test connection to services:
```bash
kubectl expose deployment/nginx
```

Expected output:
```
service "nginx" exposed
```

Spin up a 3rd pod to test its connection with the previously created 2 pods
```bash
kubectl run busybox --image=radial/busyboxplus:curl --command -- sleep 3600
```

Expected output:
```
deployment.apps/busybox created
```

```bash
# retrieve the name of busybox pod and store it in this variable
BUSYBOX_POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}") && echo $BUSYBOX_POD_NAME
```

Test busybox pod:
first get the IP addresses of the 2 NGINX pods
```
kubectl get ep nginx
```
> ep stands for endpoints

Expected output:
```
NAME    ENDPOINTS                       AGE
nginx   10.200.0.2:80,10.200.192.1:80   16m
```

Test connectivity using the previously set $BUSYBOX_POD_NAME variable:
```bash
# curl address of pod 1
kubectl exec $BUSYBOX_POD_NAME -- curl 10.200.0.2 && \
kubectl exec $BUSYBOX_POD_NAME -- curl 10.200.192.1
```

> port 80 isn't specified with the IP as it's the default port


<details>
<summary>Expected output:</summary>
<p>

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   991k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   363k      0 --:--:-- --:--:-- --:--:--  597k

```

</p>
</details>


Test connectivity to services:
```
kubectl get svc
```

Expected output:
```
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.32.0.1    <none>        443/TCP   2d18h
nginx        ClusterIP   10.32.0.41   <none>        80/TCP    24m
```

curl the nginx service address:
```
kubectl exec $BUSYBOX_POD_NAME -- curl -v 10.32.0.41
```

>We can also get the IP using kubectl get svc -o jsonpath="{.items[1].spec.clusterIP}"

<details>
<summary>Expected output:</summary>
<p>

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   109k      0 --:--:-- --:--:-- --:--:--  119k

```

</p>
</details>

---

### Clean up after the tests:

delete the deployments:
```
kubectl delete deployment {busybox,nginx}
```

Output:
```
deployment.extensions "busybox" deleted
deployment.extensions "nginx" deleted
```

delete the nginx service
```
kubectl delete svc nginx
```

Output:
```
service "nginx" deleted
```


Next: [Deploying the DNS Cluster Add-on](12-dns-addon.md)
