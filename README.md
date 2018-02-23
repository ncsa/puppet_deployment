# Usage

## VM (or live host) quickstart
1. COMMON (for both master and agent nodes)
   1. `yum -y install git vim && yum -y upgrade && reboot`
   1. `cd /root; git clone https://github.com/ncsa/puppet_deployment.git`
   1. (optional) \
      `yum -y install $( cat puppet_deployment/scripts/helper_pkgs.txt )`
1. MASTER
   1. `mkdir /backups`
   1. Copy backup tar.gz file into `/backups/.`
   1. `/root/puppet_deployment/doit.vm master`
   1. `hostname -I` #Use this ip for agent setup (-p option)
1. AGENT (relevant for testing in VM infrastructure)
   1. `/root/puppet_deployment/doit.vm -p <IPADDR> agent [hostname.fqdn]` \
      ...where `<IPADDR>` is the ip of the puppet master \
      ...where `hostname.fqdn` is optional and allows the VM agent to impersonate
      a live node that already exists in the puppet master's ENC.

## Docker
1. MASTER
   1. `doit.docker master`
1. AGENT (relevant for testing in VM infrastructure)
   1. `doit.docker agent [hostname.fqdn]`
