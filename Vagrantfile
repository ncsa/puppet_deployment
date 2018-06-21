# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# Get values from yaml config file
# (See also: https://stackoverflow.com/a/26394449 )
conf = YAML.load_file( "vagrant_conf.yaml" )
guests = conf['guests']

# Set environment variables inside guests
# Similar to https://github.com/hashicorp/vagrant/issues/7015
# but store cmdstring in a hash instead of a variable
# so that cmdstring can be unique per guest
setenv = {}
guests.each do |key, data|
    setenv[key]="tee \"/etc/profile.d/setenv.sh\" > \"/dev/null\" <<ENDHERE"
    data['env'].each do |varname, val|
        setenv[key]="#{setenv[key]}\nexport #{varname}=\"#{val}\""
    end
    setenv[key]="#{setenv[key]}\nENDHERE"
end

Vagrant.configure("2") do |config|
    # Loop through guest definitions
    guests.each do |key, data|
        config.vm.define key do |k|
            k.vm.box = data['box']
            k.vm.hostname = data['hostname']
            k.vm.network "private_network", ip: data['ip']
            k.vm.provider :virtualbox do |vb|
                vb.memory = data['memory']
            end
            k.vm.provision "shell", inline: setenv[key], run: "always"
            k.vm.provision "shell", inline: 'ln -s /vagrant /root/puppet_deployment'
        end
    end

end
