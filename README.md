# Quickstart

## Vagrant
1. `git clone https://github.com/ncsa/puppet_deployment.git`
1. `cd puppet_deployment`
1. _(optional)_ Edit _vagrant_conf.yaml_ before starting VM's
   * For master node, set environment variables:
     * PUPBUILDTYPE=master
     * PUPCONFIGTYPE (valid values: _new_, _restore_, _r10k_) (_See below for more details_)
     * PUPBKUPDIR=_\<path to directory where puppet_backup.tgz exists\>_
   * For agent node(s), set environment variables:
     * PUPBUILDTYPE=agent
     * PUPMASTER=_\<ip address of master node from above\>_
     * PUPCERTNAME=_<override hostname if desired>_ (this is optional, puppet will default to use hostname if this is unset)
1. `vagrant up`
1. `vagrant ssh master`
   1. `sudo su -`
   1. `/root/puppet_deployment/puppet_install`
1. `vagrant ssh agent`
   1. `sudo su -`
   1. `/root/puppet_deployment/puppet_install`
   1. `puppet agent -t`


## Physical Host (or other VM)
### Common
For both master and agent nodes
1. `yum -y install git; yum -y upgrade && reboot`
1. `cd /root; git clone https://github.com/ncsa/puppet_deployment.git`
1. (optional) \
   `< /root/puppet_deployment/scripts/helper_pkgs.txt xargs yum -y install`
### MASTER
#### Restore From Backup
1. `mkdir /backups`
1. Copy backup tar.gz file into `/backups/.`
1. `export PUPBKUPDIR=/backups`
1. `export PUPBUILDTYPE=master`
1. `export PUPCONFIGTYPE=restore`
1. `/root/puppet_deployment/puppet_install`
1. `hostname -I | xargs -n1 echo | grep 192.168` #Use this ip for agent setup
#### Deploy R10K Puppet Server
1. `mkdir /backups`
1. Copy backup tar.gz file into `/backups/.`
1. `export PUPBKUPDIR=/backups`
1. `export PUPBUILDTYPE=master`
1. `export PUPCONFIGTYPE=r10k`
1. `/root/puppet_deployment/puppet_install`
1. Edit `/root/puppet_deployment/r10k/r10k_init.pp`
1. `/root/puppet_deployment/r10k/r10k_init.sh`
1. TODO
   1. Configure r10k post-run script to:
      1. run `puppet generate types` for each environment
   1. Can this be included in `r10k_init.pp`?
      1. See: https://github.com/voxpupuli/puppet-r10k/blob/master/manifests/config.pp
1. `hostname -I | xargs -n1 echo | grep 192.168` #Use this ip for agent setup
### AGENT
Relevant for testing in VM infrastructure
1. `export PUPBUILDTYPE=agent`
1. `export PUPMASTER=<IPADDR>` \
    ...where `<IPADDR>` is the ip of the puppet master
1. (optional) \
   `export PUPCERTNAME=<hostname.fqdn>` \
    ...where `hostname.fqdn` is optional and allows the VM agent to impersonate \
       a live node that already exists in the puppet master's ENC.
1. `/root/puppet_deployment/puppet_install`
1. (optional) configure attached volume
   ```
   parted <device> mklabel gpt unit '%' mkpart '/qserv' 0 100
   mkfs -t xfs -L '/qserv' <device>
   ```
1. puppet agent -t

# Migrate legacy deployment to r10k deployment
1. Create and populate _control_ repo(s)
   1. Do _Restore From Backup_ (above)
   1. Connect to puppet master VM
      1. `/root/puppet_deployment/r10k/populate_from_legacy.sh`
         1. Use `-h` commandline flag for help.
   1. Destroy puppet master VM
1. Deploy R10K Puppet Server
   1. Do _Deploy R10K Puppet Server_ (above)

