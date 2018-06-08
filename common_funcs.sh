#!/bin/bash


die() {
    echo "ERROR (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
    exit 99
}


log() {
    [[ $VERBOSE -ne 1 ]] && return
    echo "INFO (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}


dumpvars() {
    [[ $VERBOSE -eq 1 ]] || return 0
    for a in $*; do
        printf "%s=%s\n" $a ${!a}
    done
}


ask_yes_no() {
    local rv=1
    local msg="Is this ok?"
    [[ -n "$1" ]] && msg="$1"
    echo "$msg"
    select yn in "Yes" "No"; do
        case "$yn" in
            Yes) rv=0;;
            No ) rv=1;;
        esac
        break
    done
    return "$rv"
}


ip_increment() {
    [[ $DEBUG -eq 1 ]] && set -x
    ipstart="$1"
    incr="$2"
    echo "$ipstart $incr" \
    | awk -v "incr=$incr" -F. '{ printf( "%d.%d.%d.%d", $1, $2, $3, $4 + incr ) }'
}
