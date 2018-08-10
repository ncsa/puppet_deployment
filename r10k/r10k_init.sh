#!/bin/bash

R10K_VERSION=6.6.1
BASE=/root/puppet_deployment

PUPPET=/opt/puppetlabs/bin/puppet
COMMON=$BASE/common_funcs.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"

# Remove unused (default) global hiera.yaml 
rm -f /etc/puppetlabs/puppet/hiera.yaml

# Install r10k
$PUPPET module install puppet-r10k --version $R10K_VERSION
$PUPPET apply $BASE/r10k/r10k_init.pp
