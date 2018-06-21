# Functions from https://github.com/bertvv/ansible-skeleton/ 

# Set options for the network interface configuration. All values are
# optional, and can include:
# - ip (default = DHCP)
# - netmask (default value = 255.255.255.0
# - mac
# - auto_config (if false, Vagrant will not configure this network interface
# - intnet (if true, an internal network adapter will be created instead of a
#   host-only adapter)
def network_options(host)
  options = {}

  if host.key?('ip')
    options[:ip] = host['ip']
    options[:netmask] = host['netmask'] ||= '255.255.255.0'
  else
    options[:type] = 'dhcp'
  end

  options[:mac] = host['mac'].gsub(/[-:]/, '') if host.key?('mac')
  options[:auto_config] = host['auto_config'] if host.key?('auto_config')
  options[:virtualbox__intnet] = true if host.key?('intnet') && host['intnet']
  options
end

def custom_synced_folders(vm, host)
  return unless host.key?('synced_folders')
  folders = host['synced_folders']

  folders.each do |folder|
    vm.synced_folder folder['src'], folder['dest'], folder['options']
  end
end


# Set options for shell provisioners to be run always. If you choose to include
# it you have to add a cmd variable with the command as data.
# 
# Use case: start symfony dev-server
#
# example: 
# shell_always:
#   - cmd: php /srv/google-dev/bin/console server:start 192.168.52.25:8080 --force
def shell_provisioners_always(vm, host)
  if host.has_key?('shell_always')
    scripts = host['shell_always']

    scripts.each do |script|
      vm.provision "shell", inline: script['cmd'], run: "always"
    end
  end
end


# Adds forwarded ports to your vagrant machine so they are available from your phone
#
# example: 
#  forwarded_ports:
#    - guest: 88
#      host: 8080
def forwarded_ports(vm, host)
  if host.has_key?('forwarded_ports')
    ports = host['forwarded_ports']

    ports.each do |port|
      vm.network "forwarded_port", guest: port['guest'], host: port['host']
    end
  end
end



# Set environment variables inside guests
# Based on https://github.com/hashicorp/vagrant/issues/7015
def setenv( vm, host )
    return unless host.key?('env')
    cmd="tee \"/etc/profile.d/setenv.sh\" > \"/dev/null\" <<ENDHERE"
    host['env'].each do |key, val|
        cmd="#{cmd}\nexport #{key}=\"#{val}\""
    end
    cmd="#{cmd}\nENDHERE"
    vm.provision "shell", inline: cmd, run: "always"
end

# -*- mode: ruby -*-
# vi: ft=ruby :
