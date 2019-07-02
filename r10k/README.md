

# Setup R10K
1. Edit `r10k.tmpl.yaml`
1. export GITSERVER=lsst-git.ncsa.illinois.edu
1. `install.sh -d -k -g $GITSERVER`
1. Edit `/root/.ssh/config`
1. Add contents of `/etc/puppetlabs/r10k/ssh/id_ed25519.pub` to gitlab server as deploy key for each repo that access is needed
