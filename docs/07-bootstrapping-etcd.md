### What is etcd:

* distributed Key-Value store that stores data across a **distributed cluster of machines** and makes sure the data is synchronized.

* etcd stores all data about **cluster-state**

* installed on all the **master | controller** nodes

* The 2 etcd services installed on master nodes will be communicating with each other to form an **etcd-cluster**

### Prerequisites

The commands in this lab must be run on each controller instance: `master-1` and `master-2` so ssh into these vagrant machines.

### Running commands in parallel with tilix:

I'm using tilix with a set of custom shortcuts, [config file is here](https://gist.github.com/theJaxon/592c33892c52e0e096f73b4e88119d9f) so i split the terminal with `$mod+h` then `$mod+s` to sync the input between the 2 terminals.

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

Download the official etcd release binaries from the [etcd](https://github.com/etcd-io/etcd) GitHub project:

```bash
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```bash
tar -xvf etcd-v3.4.0-linux-amd64.tar.gz && sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
```

### Configure the etcd Server

```bash
sudo mkdir -p /etc/etcd /var/lib/etcd && sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current compute instance:

```bash
# master-1 machine
ETCD_NAME=master-1.com && echo $ETCD_NAME

# master-2 machine
ETCD_NAME=master-2.com && echo $ETCD_NAME
```

Set the internal IP for each machine in an environment variable:
```bash
# master-1 machine
INTERNAL_IP=192.168.11.11 && echo $INTERNAL_IP

# master-2 machine
INTERNAL_IP=192.168.11.12 && echo $INTERNAL_IP
```

Allow the 2 nodes to communicate by setting the initial cluster:
the initial cluster variable is [$ETCD_NAME of master-1]=[https://$INTERNAL_IP of master-1:2380],[$ETCD_NAME of master-2]=[https://$INTERNAL_IP of master-2:2380]

```bash
INITIAL_CLUSTER=master-1.com=https://192.168.11.11:2380,master-2.com=https://192.168.11.12:2380 && echo $INITIAL_CLUSTER
```

Create the `etcd.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${INITIAL_CLUSTER} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start and enable the etcd Server:

```bash
sudo systemctl daemon-reload && sudo systemctl enable etcd --now
```

> Remember to run the above commands on each master node: `master-1` and `master-2`.

## Verification

List the etcd cluster members:

```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

> output

```
1cc1c30827a7e2b2, started, master-2.com, https://192.168.11.12:2380, https://192.168.11.12:2379, false
5da3ae547f1355df, started, master-1.com, https://192.168.11.11:2380, https://192.168.11.11:2379, false

```

List the etcd cluster members showing current leader:
```bash
sudo ETCDCTL_API=3 etcdctl endpoint status --write-out=table   --endpoints=https://127.0.0.1:2379   --cacert=/etc/etcd/ca.pem   --cert=/etc/etcd/kubernetes.pem   --key=/etc/etcd/kubernetes-key.pem
```

> output

```bash
# master-1
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://127.0.0.1:2379 | 5da3ae547f1355df |   3.4.0 |   25 kB |     false |      false |         2 |          6 |                  6 |        |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

# master-2
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://127.0.0.1:2379 | 1cc1c30827a7e2b2 |   3.4.0 |   25 kB |      true |      false |         2 |          6 |                  6 |        |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

```

Next: [Bootstrapping the Kubernetes Control Plane](08-bootstrapping-kubernetes-controllers.md)
