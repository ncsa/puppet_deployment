#!/bin/bash

PUPPET=/opt/puppetlabs/bin/puppet
ENVDIR=$( $PUPPET config print environmentpath )

now=$(date +%s)
for env in $(ls -d $ENVDIR/*); do
    manifestdir=$env/site/role/manifests
    find $manifestdir -mindepth 1 -maxdepth 1 -name '*.pp' \
    | while read; do
        bak=${REPLY}.$now
        cp $REPLY $bak
        awk '
/allow_qualys_scan/ && ! /#/ { print "#",$0; next }
/gpfs/              && ! /#/ { print "#",$0; next }
/telegraf/          && ! /#/ { print "#",$0; next }
/yum_client/        && ! /#/ { print "#",$0; next }
/slurm/             && ! /#/ { print "#",$0; next }
{print}
' $bak > $REPLY
    done
done

