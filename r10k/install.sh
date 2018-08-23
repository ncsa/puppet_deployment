#!/bin/bash

MODULE_NAME=r10k
MODULE_VERSION=6.6.1
BASE=/root/puppet_deployment
MANIFEST=$BASE/$MODULE_NAME/manifest.pp
PUPPET=/opt/puppetlabs/bin/puppet
COMMON=$BASE/common_funcs.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"


prerun() {
    # Remove unused (default) global hiera.yaml 
    rm -f /etc/puppetlabs/puppet/hiera.yaml
}


puppet_module_install() {
    # Install puppet module
    $PUPPET module install puppet-$MODULE_NAME --version $MODULE_VERSION
}


puppet_module_apply() {
    # Perform service install
    $PUPPET apply --test $MANIFEST

}


postrun() {
    # Clean up install junk from global modules dir
    local paths=( $( puppet config print modulepath | tr ':' ' ' ) )
    for dir in "${paths[@]}"; do
        find $dir -mindepth 1 -delete
    done
}

set -x

prerun

puppet_module_install

puppet_module_apply

postrun
