#!/bin/bash


function croak {
    echo "ERROR (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
    exit 99
}


function log() {
    [[ $VERBOSE -ne 1 ]] && return
    echo "INFO (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}


function dumpvars() {
    [[ $VERBOSE -eq 1 ]] || return 0
    for a in $*; do
        printf "%s=%s\n" $a ${!a}
    done
}


function ip_increment() {
    [[ $DEBUG -eq 1 ]] && set -x
    ipstart="$1"
    incr="$2"
    echo "$ipstart $incr" \
    | awk -v "incr=$incr" -F. '{ printf( "%d.%d.%d.%d", $1, $2, $3, $4 + incr ) }'
}
