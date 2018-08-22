#!/bin/bash

MODULE_NAME=r10k
MODULE_VERSION=6.6.1
BASE=/root/puppet_deployment
CONFDIR=$BASE/r10k
CODEDIR=$BASE/r10k/code
YAML=$CONFDIR/data/common.yaml
PUPPET=/opt/puppetlabs/bin/puppet
COMMON=$BASE/common_funcs.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"


get_remotes_from_yaml() {
    # Parse YAML and print unique hostsnames from the remotes
    python36 - <<ENDPYTHON
import yaml
with open($YAML) as fh
    data = yaml.safe_load( fh )
remotes=[]
for v in data['r10k::sources'].values():
    remotes.append( v['remote'].split('@')[1].split(':')[0] )
[ print(x) for x in set(remotes) ]
ENDPYTHON
}


populate_knownhosts() {
    # Attempt to pre-populate knownhosts file
    local hosts=( $(get_remotes_from_yaml) )
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


prerun() {
    # Remove unused (default) global hiera.yaml 
    rm -f /etc/puppetlabs/puppet/hiera.yaml
}


puppet_module_install() {
    # Install puppet module
    $PUPPET module install puppet-$MODULE_NAME \
        --basemodulepath $CODEDIR \
        --modulepath $CODEDIR \
        --confdir $CONFDIR \
        --version $MODULE_VERSION
}


puppet_module_apply() {
    # Perform service install
    $PUPPET apply \
        --test \
        --basemodulepath $CODEDIR \
        --modulepath $CODEDIR \
        --confdir $CONFDIR \
        --execute "include $MODULE_NAME"
}


postrun() {
    : #pass
}

set -x

prerun

populate_knownhosts

puppet_module_install

puppet_module_apply

postrun
