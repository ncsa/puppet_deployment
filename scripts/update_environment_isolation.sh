#!/bin/bash

envpath=$( puppet config print environmentpath )
elist=( $( ls $envpath ) )
for e in "${elist[@]}" ; do
    rname=$envpath/$e/.resource_types
    [[ -e $rname ]] && find $envpath/$e/.resource_types -delete
    [[ -e $rname ]] && {
        echo "FATAL: Existing resource_types found '$rname'" >&2
        exit 1
    }
    set -x
    puppet generate types --force --environment $e
    set +x
done
