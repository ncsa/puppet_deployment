#!/bin/bash

BASE=/root/r10k_deployment
PUPPET=/opt/puppetlabs/bin/puppet
COMMON=$BASE/common.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"

# Populate control_repo

# Populate hiera repo
