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
    [[ $DEBUG -eq 1 ]] && set -x
    local netname=$1
    docker network ls --format '{{.Name}}' | grep -q "$netname"
}


function mk_user_net() {
    [[ $DEBUG -eq 1 ]] && set -x
    local netname=$1
    # Create if needed
    if netname_exists "$netname" ; then
        return
    else
        docker network create --driver bridge --subnet="$NETCIDR" "$netname"
        # Verify netname exists
        netname_exists "$netname" \
        || croak "Unable to create network '$netname'"
    fi
}


function sanepath() {
    [[ $DEBUG -eq 1 ]] && set -x
    path=$( readlink -e "$1" )
    if [[ "${#WINDRIVE}" -gt 0 ]] ; then
        echo "$path" \
        | sed -e "s|^/mnt/$WINDRIVE/|${WINDRIVE^}:/|" \
        | sed -e 's|/|\\|g'
    else
        echo "$path"
    fi
}


function ip_increment() {
    [[ $DEBUG -eq 1 ]] && set -x
    ipstart="$1"
    incr="$2"
    echo "$ipstart $incr" \
    | awk -v "incr=$incr" -F. '{ printf( "%d.%d.%d.%d", $1, $2, $3, $4 + incr ) }'
}
