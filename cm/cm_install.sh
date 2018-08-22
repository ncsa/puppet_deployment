#!/bin/bash

MODULE_VERSION=2.1.0
BASE=/root/puppet_deployment
CONFDIR=$BASE/cm
CODEDIR=$BASE/cm/code
PUPPETLABS=/etc/puppetlabs
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

install() {
    # Install gitlab puppet module
    $PUPPET module install puppet-gitlab \
        --basemodulepath $CODEDIR \
        --modulepath $CODEDIR \
        --confdir $CONFDIR \
        --version $MODULE_VERSION
}

apply() {
    # Perform gitlab install
    $PUPPET apply \
        --test \
        --basemodulepath $CODEDIR \
        --modulepath $CODEDIR \
        --confdir $CONFDIR \
        --execute 'include gitlab'
}

postrun() {
    : #pass
}

set -x

prerun

install

apply

postrun
