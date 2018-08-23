#!/bin/bash

MODULE_VERSION=2.1.0
MODULE_NAME=gitlab
BASE=/root/puppet_deployment
CONFDIR=$BASE/git
CODEDIR=$BASE/git/code
PUPPET=/opt/puppetlabs/bin/puppet
COMMON=$BASE/common_funcs.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"

prerun() {
    : #pass
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
    # Perform gitlab install
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

puppet_module_install

puppet_module_apply

postrun
