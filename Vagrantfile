# -*- mode: ruby -*-
# vi: set ft=ruby :
# Verify and install required plugins
required_plugins = %s(vagrant-sshfs)
# TODO: Should we auto-update these?
if ENV['VAGRANT_PLUGINS_UPDATED']=='true'
   alreadyUpdated = 'true'
end
if alreadyUpdated != 'true' && (ARGV[0] == "up" || ARGV[0] == "provision")
  system "vagrant plugin install #{required_plugins}"
  system "vagrant plugin update #{required_plugins}"
  ENV['VAGRANT_PLUGINS_UPDATED'] = 'true'
  # Restart vagrant after plugin updates
  exec "vagrant #{ARGV.join(' ')}"
end


Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vm.network "private_network", type: "dhcp"

  config.vm.synced_folder ".", "/vagrant", type: "sshfs"
  config.vm.provision "shell", inline: "sudo yum -y update"

  config.vm.provision "shell", inline: "sudo yum -y install git"

  config.vm.provision "ansible_local" do |ansible|
    ansible.provisioning_path = '/vagrant/ansible'
    ansible.playbook = "playbook.yml"
    ansible.galaxy_roles_path = 'roles'
    ansible.galaxy_role_file = "requirements.yml"
    ansible.limit = 'all'
  end
   
  config.vm.provision "shell", path: "ansible/cd-provisioner.sh", privileged: false
  config.vm.network "forwarded_port", host: 3333, guest: 3000
  config.vm.network "forwarded_port", host: 6379, guest: 6379
  config.vm.network :forwarded_port, guest: 80, host: 4567

  #config.vm.provision "shell", inline: "/bin/sh /vagrant/ffmpeg.sh", privileged: false
  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end
