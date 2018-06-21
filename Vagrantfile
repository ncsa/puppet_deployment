# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
load 'vagrant_funcs.rb'

# Get values from yaml config file
# (See also: https://stackoverflow.com/a/26394449 )
conf = YAML.load_file( "vagrant_conf.yaml" )
guests = conf['guests']
defaults = conf['defaults']


Vagrant.configure("2") do |config|
    # Loop through guest definitions
    guests.each do |nodename, nodedata|
        config.vm.define nodename do |node|
            node.vm.box = nodedata['box'] ||= defaults['box']
            node.vm.hostname = nodedata['hostname'] if nodedata.key? 'hostname'
            node.vm.network "private_network", network_options( nodedata )
            node.vm.provider :virtualbox do |vb|
                vb.memory = nodedata['memory'] ||= defaults['memory']
            end

            setenv( node.vm, nodedata )

            #node.vm.provision "shell", inline: 'ln -s /vagrant /root/puppet_deployment'
            custom_synced_folders( node.vm, nodedata )
        end
    end

end
