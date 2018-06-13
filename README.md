# Usage

## VM (or live host) quickstart
### Common
For both master and agent nodes
1. `yum -y install git; yum -y upgrade && reboot`
1. `cd /root; git clone https://github.com/ncsa/puppet_deployment.git`
1. (optional) \
   `< /root/puppet_deployment/scripts/helper_pkgs.txt xargs yum -y install`
### MASTER
#### Restore *R10K* Deployment
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
      1. create symlink for each hiera data dir
      1. run `puppet generate types` for each environment
   1. Can this be included in `r10k_init.pp`?
1. `hostname -I` #Use this ip for agent setup
#### Restore Legacy Deployment
1. `mkdir /backups`
1. Copy backup tar.gz file into `/backups/.`
1. `export PUPBKUPDIR=/backups`
1. `export PUPBUILDTYPE=master`
1. `export PUPCONFIGTYPE=r10k`
1. `/root/puppet_deployment/puppet_install`
1. `hostname -I` #Use this ip for agent setup
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

## Docker
(Warning: needs more work, suffers from `Failed to get D-Bus connection:
operation not permitted.`).
1. MASTER
   1. `doit.docker master`
1. AGENT (relevant for testing in VM infrastructure)
   1. `doit.docker agent [hostname.fqdn]`

# Migrate legacy deployment to r10k deployment
1. Do _Restore Legacy Master_ (above) or run the following on production master \
   Note that the output will be written to `OUTPUT_PATH`. \
   Source files remain untouched.
1. Extract puppet backup somewhere (not needed if running on the production master)
1. `/root/puppet_deployment/r10k/populate_from_legacy.sh
   -M MODULES_PATH
   -D HIERA_DATA_PATH
   -O OUTPUT_PATH
   -C CONTROL_REPO_NAME
   -H HIERA_REPO_NAME
   `

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
