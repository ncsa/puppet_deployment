# Summary
Define a process to (re-)build, from scratch, a configuration management environment consisting of a version controlled Data Store (gitlab) and OS Configuration Manager (puppet). The initial purpose is to provide a migration path from a *legacy* (outdated, manual) puppet setup to a more recent, automated setup managed by *r10k*.

# Test setup using Vagrant
The vagrant definitions and scripts are useful to provide a test of the scripts and of the overall deployment model.
The vagrant VM's are all based on CentOS 7.5.

### Install
1. `curl https://raw.githubusercontent.com/ncsa/puppet_deployment/master/scripts/centos75_post.sh | bash`
1. `git clone https://github.com/ncsa/puppet_deployment.git`
1. `cd puppet_deployment`
### Review configuration
1. _(optional)_ Review configuration
   1. Relevant configuration files
      1. `puppet_install` (especially PUPPET_REPO_URL)
      1. `vagrant_conf.yaml` (if using Vagrant)
      1. `gitlab/data/common.yaml`
      1. `r10k/r10k/populate_from_legacy.sh` (only if migrating from legacy config)
      1. `r10k/r10k.tmpl.yaml`
      1. `scripts/disable_non_vm_friendly_profiles.sh` (for testing from Vagrant)
1. _(optional)_ Create a common `.ssh` setup (enables automated git access from the puppet master)
   1. `mkdir .ssh`
   1. `ssh-keygen -t ecdsa -b 521 -f .ssh/id_ecdsa`
   1. `echo 'User atestuser' >.ssh/config`
   1. `echo 'IdentityFile /vagrant/.ssh/id_ecdsa' >>.ssh/config`
   1. `echo 'StrictHostKeyChecking no' >>.ssh/config`
   1. `chmod 0600 .ssh/*`
   1. `chmod 0700 .ssh`
### Gitlab
1. Create a Gitlab server
   1. `vagrant up git`
   1. `/root/puppet_deployment/gitlab/install.sh`
   1. Login to web interface
      1. Create a user
         1. If you created a common `.ssh` config above, use that username
      1. Add SSH key
      1. Create group
         1. Note that the group name should match that in `r10k/manifest.pp`
### Puppet Master
1. `vagrant up new`
1. `vagrant ssh new`
   1. `sudo su -`
   1. `/root/puppet_deployment/scripts/disable_non_vm_friendly_profiles.sh`
   1. `git clone git@git.ncsa.illinois.edu:lsst/puppet/local.git /etc/puppetlabs/local`
   1. `/etc/puppetlabs/local/scripts/configure_enc.sh`
   1. `/root/puppet_deployment/r10k/install.sh`
   1. `r10k deploy environment -p -v debug`
   1. `/opt/puppetlabs/bin/puppetserver start`
   1. `lsof -i :8140`
### Puppet Agent
1. `vagrant up agent01`
1. `vagrant ssh agent01`
   1. `sudo su -`
   1. `puppet agent -t`


# Deploy for production (on a physical host or other VM)
### Common
For both gitlab and puppet master nodes
1. `curl https://raw.githubusercontent.com/ncsa/puppet_deployment/master/scripts/centos75_post.sh | bash`
1. `cd /root; git clone https://github.com/ncsa/puppet_deployment.git`

### Gitlab
1. _(**Common** steps from above)_
1. `/root/puppet_deployment/puppet_install -a -d`
1. Edit `/root/puppet_deployment/gitlab/data/common.yaml`
1. `/root/puppet_deployment/gitlab/install.sh`
1. _TODO: restore from backup_
### Puppet master
1. _(**Common** steps from above)_
1. `/root/puppet_deployment/puppet_install -m -M new -d`
1. `git clone https://git.ncsa.illinois.edu/lsst/puppet/local.git /etc/puppetlabs/local`
1. Edit `/etc/puppetlabs/local/enc/puppet_enc_sqlite_source.csv`
1. `/etc/puppetlabs/local/scripts/configure_enc.sh`
1. Edit `/root/puppet_deployment/r10k/r10k.tmpl.yaml`
1. `/root/puppet_deployment/r10k/install.sh`
1. `r10k deploy environment -p -v debug`


# Sample - Migrate legacy deployment to r10k deployment
This is best done using vagrant, since there is no need to keep the contents once the repos are published to a gitlab server.
1. `git clone https://github.com/ncsa/puppet_deployment.git`
1. `cd puppet_deployment`
1. `mkdir /backups`
1. Copy backup tar.gz file into `/backups/.`
1. `vagrant up legacy`
1. `vagrant ssh legacy`
   1. `sudo su -`
   1. `/root/puppet_deployment/r10k/populate_from_legacy.sh -G git@GITLAB.SERVER:PROJECTNAME`
      1. Where `git@GITLAB.SERVER:PROJECTNAME` is the base url for where puppet control repo's will live

Puppet control repos are now created and populated on _GITLAB.SERVER_ in project _PROJECTNAME_

# Future work
* Backup procedure for gitlab server content (and config?)
* Ability to __restore from backup__ for gitlab deployment
* (Re-)Deploy procedure for hardware provisioning (xCAT)
