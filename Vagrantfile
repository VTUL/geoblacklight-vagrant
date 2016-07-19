# -*- mode: ruby -*-
# vi: set ft=ruby :

# To install under OpenStack the Vagrant openstack provider needs to be installed.
# You can install this plugin by running the following command:
#
#   vagrant plugin install vagrant-openstack-plugin
#
# To install under AWS you need to have the vagrant-aws provider plugin installed.
# You can install this using the following command:
#
#   vagrant plugin install vagrant-aws
#
# If no "--provider" is specified during "vagrant up" then the default
# (VirtualBox) provider will be used.

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  # Providers
  config.vm.provider :virtualbox do |vb, override|
    override.vm.network :private_network, ip: "192.168.0.2"
    # Customize the amount of memory on the VM:
    vb.memory = "3072"
    override.vm.provision :shell, path: "install_geoblacklight.sh", args: "vagrant"
  end

  config.vm.provider :aws do |aws, override|
    keypair = "#{ENV['KEYPAIR_NAME']}"
    keypair_filename = "#{ENV['KEYPAIR_FILE']}"
    override.vm.box = "aws_dummy"
    override.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    override.vm.box_check_update = false
    aws.access_key_id = ENV['AWS_ACCESS_KEY']
    aws.secret_access_key = ENV['AWS_SECRET_KEY']
    aws.keypair_name = keypair
    aws.ami = "ami-df0607b5" # Ubuntu Trusty LTS
    aws.region = "us-east-1"
    aws.instance_type = "t2.small"
    aws.security_groups = ["default_vpc_web_vt_ssh"]
    #aws.associate_public_ip = true
    override.ssh.username = "ubuntu"
    override.ssh.private_key_path = "#{keypair_filename}"
    aws.tags = {
      'Name' => "GeoBlacklight #{keypair}"
    }
    override.vm.provision :shell, path: "install_geoblacklight.sh", args: "ubuntu"
  end

  config.vm.provider :openstack do |os, override|
    keypair = "#{ENV['KEYPAIR_NAME']}"
    keypair_filename = "#{ENV['KEYPAIR_FILE']}"
    override.vm.box = "openstack_dummy"
    override.vm.box_url = "https://github.com/cloudbau/vagrant-openstack-plugin/raw/master/dummy.box"
    override.vm.box_check_update = false
    override.ssh.private_key_path = "#{keypair_filename}"
    os.username     = "#{ENV['OS_USERNAME']}"  # e.g. "#{ENV['OS_USERNAME']}"
    os.api_key      = "#{ENV['OS_PASSWORD']}"  # e.g. "#{ENV['OS_PASSWORD']}"
    os.flavor       = /m1.medium/               # Regex or String
    os.image        = /Ubuntu-Server-14.04-LTS/# Regex or String
    os.endpoint     = "#{ENV['OS_AUTH_URL']}/tokens" # e.g. "#{ENV['OS_AUTH_URL']}/tokens"
    os.keypair_name = keypair # as stored in Nova
    os.ssh_username = "cc"           # login for the VM
    os.security_groups = ['web', 'vt-ssh']
    os.floating_ip  = "#{ENV['OS_FLOATING_IP']}"
    os.server_name  = "GeoBlacklight"
    os.tenant       = "#{ENV['OS_TENANT_NAME']}"
    os.region       = "#{ENV['OS_REGION_NAME']}"
    override.vm.provision :shell, path: "install_geoblacklight.sh", args: "cc"
  end
end
