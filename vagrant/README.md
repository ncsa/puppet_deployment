# Test setup using Vagrant
The vagrant definitions and scripts are useful to provide a test of the scripts and of the overall deployment model.
The vagrant VM's are all based on CentOS.

## Install
1. `git clone https://github.com/ncsa/puppet_deployment.git`
1. `cd puppet_deployment/vagrant`
## Review configuration
1. _(optional)_ Review configuration files
   1. Relevant configuration files
      1. `puppet/install.sh` (especially PUPPET_REPO_URL)
      1. `gitlab/data/common.yaml`
      1. `r10k/r10k.tmpl.yaml`
      1. `scripts/disable_non_vm_friendly_profiles.sh` (for testing from Vagrant)
   1. Set appropriate environment variables in `vagrant_conf.yaml`
## Puppet Master
1. `vagrant up new`
1. `vagrant ssh new`
   1. `sudo su -`
   1. `/root/puppet_deployment/scripts/disable_non_vm_friendly_profiles.sh`
   1. Setup ENC
      1. See: https://github.com/ncsa/puppetserver-local
   1. `/root/puppet_deployment/r10k/install.sh`
   1. `r10k deploy environment -p -v debug`
   1. `/opt/puppetlabs/bin/puppetserver start`
   1. `lsof -i :8140`
## Puppet Agent
1. `vagrant up agent01`
1. `vagrant ssh agent01`
   1. `sudo su -`
   1. `puppet agent -t`

# Miscellaneous
## Gitlab
1. Create a Gitlab server
   1. `vagrant up git`
   1. `/root/puppet_deployment/gitlab/install.sh`
   1. Login to web interface
      1. Create a user
         1. If you created a common `.ssh` config above, use that username
      1. Add SSH key
      1. Create group
         1. Note that the group name should match that in `r10k/manifest.pp`
1. _(optional)_ Create a common `.ssh` setup (enables automated git access from the puppet master)
   1. `mkdir .ssh`
   1. `ssh-keygen -t ed25519 -f .ssh/id_ed25519`
   1. `echo 'User atestuser' >.ssh/config`
   1. `echo 'IdentityFile /vagrant/.ssh/id_ed25519' >>.ssh/config`
   1. `echo 'StrictHostKeyChecking no' >>.ssh/config`
   1. `chmod 0600 .ssh/*`
   1. `chmod 0700 .ssh`
