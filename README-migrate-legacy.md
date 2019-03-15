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
