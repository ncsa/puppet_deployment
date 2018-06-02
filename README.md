# Usage

## Docker
1. MASTER
   1. `doit.docker master`
1. AGENT (relevant for testing in VM infrastructure)
   1. `doit.docker agent [hostname.fqdn]`

## VM (or live host) quickstart
1. COMMON (for both master and agent nodes)
   1. `yum -y install git; yum -y upgrade && reboot`
   1. `cd /root; git clone https://github.com/ncsa/puppet_deployment.git`
   1. (optional) \
      `< /root/puppet_deployment/scripts/helper_pkgs.txt xargs yum -y install`
1. MASTER
   1. `mkdir /backups`
   1. Copy backup tar.gz file into `/backups/.`
   1. `/root/puppet_deployment/doit.vm master`
   1. `hostname -I` #Use this ip for agent setup (-m option)
1. AGENT (relevant for testing in VM infrastructure)
   1. `/root/puppet_deployment/doit.vm -m <IPADDR> agent [hostname.fqdn]` \
      ...where `<IPADDR>` is the ip of the puppet master \
      ...where `hostname.fqdn` is optional and allows the VM agent to impersonate
      a live node that already exists in the puppet master's ENC.
   1. (optional) configure attached volume
      ```
      parted <device> mklabel gpt unit '%' mkpart '/qserv' 0 100
      mkfs -t xfs -L '/qserv' <device>
      ```
   1. puppet agent -t

# Sample Scenario
Enable and test environment isolation
1. Setup Puppet Master
    1. (See quickstart above)
    1. https://github.com/ncsa/pupmodver
    1. Remove extraneous environments (optional)
       ```
       scripts/rm_puppet_environment.sh
       ```
    1. Make backup of puppet environments (optional)
       ```
       rsync -av --exclude '.git' /etc/puppetlabs/code/environments /etc/puppetlabs/code/env.ORIG
       ```
    1. Remove unneeded puppet modules from `test` enironment (optional)
       ```
       venv/bin/python pupmodver/pupmodver.py -e test -t | awk '
       /herculesteam-augeasproviders_core/ { modules_to_remove[$1]=1 }
       /herculesteam-augeasproviders_ssh/  { modules_to_remove[$1]=1 }
       /puppet-grafana/                    { modules_to_remove[$1]=1 }
       END {
         for ( module_name in modules_to_remove ) {
            cmd=sprintf( "puppet module uninstall %s --environment test", module_name )
            print( cmd )
            system( cmd )
         }
       }
       '
       ```
    1. Disable puppet profiles that can't be used in the virtual environment
       ```
       scripts/disable_non_vm_friendly_profiles.sh
       ```
    1. Enable puppet Environment Isolation
       ```
       scripts/update_environment_isolation.sh
       ```
1. Setup Client Node
    1. (See quickstart above)
