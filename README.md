# Summary
Define a process to (re-)build, from scratch, a configuration management environment consisting of a version controlled Data Store (gitlab) and OS Configuration Manager (puppet).


### Testing in Vagrant
See: [vagrant/README](vagrant/)


# Installation
### Common
For both gitlab and puppet master nodes
1. `curl https://raw.githubusercontent.com/ncsa/puppet_deployment/master/scripts/centos_post.sh | bash`
1. `cd /root; git clone https://github.com/ncsa/puppet_deployment.git`

### Gitlab
1. _(**Common** steps from above)_
1. `/root/puppet_deployment/puppet/install.sh -a -d`
1. Edit `/root/puppet_deployment/gitlab/data/common.yaml`
1. `/root/puppet_deployment/gitlab/install.sh`
1. _Future Work: restore from backup_

### Puppet master
1. _(**Common** steps from above)_
1. `/root/puppet_deployment/puppet/install.sh -m -V 5 -D <DNS_ALT_NAMES> -d`
   1. where <DNS_ALT_NAMES> is comma separated list of alternate names
      (note: public fqdn and local ip-addrs are automatically detected and should
      not be included in DNS_ALT_NAMES)
1. #### Configure ENC
   (This step is optional, but the custom setup (linked below) installs some r10k postrun  scripts, so is needed before r10k.)
   1. See: https://github.com/ncsa/puppetserver-local
1. #### Install and configure R10K
   1. Edit `/root/puppet_deployment/r10k/r10k.tmpl.yaml`
   1. `/root/puppet_deployment/r10k/install.sh -h`
   1. `/root/puppet_deployment/r10k/install.sh -k -v -g <GITSERVER>`
1. #### Install hostkey (created above) on git server as a deploy key
   1. See: https://docs.gitlab.com/ee/ssh/#deploy-keys
   1. Verify access
      1. `awk '/git@/{print $NF}' /etc/puppetlabs/r10k/r10k.yaml | xargs -n1 -- git ls-remote -h`
1. #### Deploy dynamic environments with r10k
   1. `/opt/puppetlabs/puppet/bin/r10k deploy environment -p -v debug 2>&1 | tee ~/r10k-deploy.log`
   1. `grep -i error ~/r10k-deploy.log`
1. #### Start puppetserver
   1. `systemctl start puppetserver`
