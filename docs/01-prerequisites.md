# Prerequisites

### [Vagrant](https://www.vagrantup.com/):
To be able to apply kuberntes the hard way locally vagrant was chosen, using [multi machine setup](https://github.com/theJaxon/kubernetes-the-hard-way/blob/master/Vagrantfile) as follows:
- 2 master nodes
- 2 worker nodes 
- 1 load balancer node 

```Ruby
IMAGE_NAME = "ubuntu/bionic64"
ADAPTER = "TP-LINK Wireless USB Adapter"
N = 2

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  # Master Nodes
  (1..N).each do |i|
    config.vm.define "master-#{i}" do |master|
      master.vm.box = IMAGE_NAME
      master.vm.hostname = "master-#{i}"
      master.vm.network "private_network", ip: "192.168.11.#{i + 10}", bridge: "#{ADAPTER}"
    end
  end

  # Worker Nodes 
  (1..N).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.box = IMAGE_NAME
      node.vm.hostname = "node-#{i}"
      node.vm.network "private_network", ip: "192.168.12.#{i + 10}", bridge: "#{ADAPTER}"
    end
  end

  # Load Balancer 
  config.vm.define "load-balancer" do |lb|
    lb.vm.box = IMAGE_NAME
    lb.vm.hostname = "load-balancer"
    lb.vm.network "private_network", ip: "192.168.13.11", bridge: "#{ADAPTER}"
  end
end
  
```

### Local DNS with /etc/hosts:
The `/etc/hosts` file was modified to match the following domain names to each machine ip as follows:
```
192.168.11.11 master-1.com 
192.168.11.12 master-2.com
192.168.12.11 node-1.com
192.168.12.12 node-2.com
192.168.13.11 load-balancer.com 
```

### Configure [Tilix](https://gnunn1.github.io/tilix-web/):
Tilix was modified to allow running command in sync, easier splitting horizontally and vertically using easy to remember shortcuts, keybindings are written next while the full config file can be found [here](https://gist.github.com/theJaxon/592c33892c52e0e096f73b4e88119d9f):
```
[keybindings]
session-add-down='<Super>h'
session-add-right='<Super>v'
session-name='<Super>r'
session-synchronize-input='<Super>s'
terminal-close='<Super>q'
```

Next: [Installing the Client Tools](02-client-tools.md)
