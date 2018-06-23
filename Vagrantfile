# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
require 'pp'
load 'vagrant_funcs.rb'

# Get values from yaml config file
# (See also: https://stackoverflow.com/a/26394449 )
conf = YAML.load_file( "vagrant_conf.yaml" )
defaults = conf['defaults']
common = conf['common']
guests = conf['guests']


Vagrant.configure("2") do |config|
    # Loop through guest definitions
    guests.each do |nodeName, nodeData|
        data = defaults.merge( nodeData )
        config.vm.define nodeName do |node|
            node.vm.box = data['box']
            node.vm.hostname = data['hostname'] if data.key? 'hostname'
            node.vm.network "private_network", network_options( data )
            node.vm.provider :virtualbox do |vb|
                vb.memory = data['memory'] if data.key? 'memory'
            end

            # Set Environment Variables
            envData = merge_child_hashes( data, common, 'env' )
#            puts "envData for node '#{nodeName}'"
#            pp envData
            setenv( node.vm, envData )

            # Synced Folders
            syncData = concat_child_arrays( data, common, 'synced_folders' )
#            puts "syncData for node '#{nodeName}'"
#            pp syncData
            custom_synced_folders( node.vm, syncData )

            # Shell Provisioners (always)
            alwaysData = concat_child_arrays( data, common, 'shell_always' )
#            puts "alwaysData for node '#{nodeName}'"
#            pp alwaysData
            shell_provisioners_always( node.vm, alwaysData )

            # Shell Provisioners (once)
            onceData = concat_child_arrays( data, common, 'shell_once' )
#            puts "onceData for node '#{nodeName}'"
#            pp onceData
            shell_provisioners_always( node.vm, onceData )

        end
    end

end
