#!/bin/bash

function croak() {
    echo "ERROR: $*" 1>&2
    exit 99
}


function dumpvars() {
    [[ $VERBOSE -eq 1 ]] || return 0
    for a in $*; do
        printf "%s=%s\n" $a ${!a}
    done
}


function netname_exists() {
    local netname=$1
    docker network ls --format '{{.Name}}' | grep -q "$netname"
}


function mk_user_net() {
    local netname=$1
    # Create if needed
    if netname_exists "$netname" ; then
        return
    else
        docker network create --driver bridge "$netname"
        # Verify netname exists
        netname_exists "$netname" \
        || croak "Unable to create network '$netname'"
    fi
}
