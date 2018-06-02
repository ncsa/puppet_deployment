#!/bin/bash

PUPPET=/opt/puppetlabs/bin/puppet
ENVDIR=$( $PUPPET config print environmentpath )

set -x
ls $ENVDIR \
| grep -v 'production\|test' \
| xargs -r -n1 -I{} find $ENVDIR/{} -delete
