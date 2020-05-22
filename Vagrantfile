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
  
