#!/bin/bash

R10K_VERSION=6.6.1
BASE=/root/puppet_deployment
PUPSRC=$BASE/r10k/r10k_init.pp
PUPPET=/opt/puppetlabs/bin/puppet
COMMON=$BASE/common_funcs.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"

populate_knownhosts() {
    # Attempt to pre-populate knownhosts file
    local hosts=( awk '
        /remote/ {
            split($NF, parts, /@/)
            split(parts[2], pieces, /:/)
            print pieces[1]
            }' \
        $PUPSRC
    )
    local new=~/.ssh/new_hosts
    local known=~/.ssh/known_hosts
    local tmp=~/.ssh/tmp_hosts
    for h in "${hosts[@]}"; do
        ssh-keyscan -t rsa,dsa,ecdsa "$h" 2>&1 >> $new \
    done
    sort -u $new $known > $tmp
    mv $tmp $known
    rm $new
}

populate_knownhosts

# Remove unused (default) global hiera.yaml 
rm -f /etc/puppetlabs/puppet/hiera.yaml

# Install r10k
$PUPPET module install puppet-r10k --version $R10K_VERSION
$PUPPET apply $PUPSRC
