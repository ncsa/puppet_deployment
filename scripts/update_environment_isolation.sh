#!/bin/bash

PRG=$( basename $0 )
PUPPET=/opt/puppetlabs/bin/puppet

function die() {
    printf 'FATAL: %s\n' "$*" >&2
    exit 1
}


function show_help() {
    cat <<ENDHERE

$PRG - Update Puppet Environment Isolation resource type files

Usage: $PRG [options]

Options:
    -h
    -?
    --help  Print this help message

    -r      Remove the .resource_types files before generating new ones

    -e ENV  Operate on environment ENV (default is to run for all environments)
ENDHERE
}


# Parse cmdline options
envlist=()
REMOVE=0
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit
            ;;
        -r)
            REMOVE=1
            ;;
        -e)
            if [[ "$2" ]]; then
                envlist=( "$2" )
                shift
            else
                die "-e option requires a non-empty argument"
            fi
            ;;
        --)
            shift
            break
            ;;
        -?*)
            die "Unknown option '$1'"
            ;;
        *)         # Default case: No more options, so break from loop
            break
            ;;
    esac
    shift
done

# Set variables that are used below
envpath=$( $PUPPET config print environmentpath )

# Check environment list
if [[ ${#envlist[*]} -lt 1 ]]; then
    envlist=( $( ls $envpath ) )
fi
if [[ ${#envlist[*]} -lt 1 ]]; then
    die "Empty environment list."
fi

# Process each environment in turn
for e in "${envlist[@]}" ; do
    # Validate environment name
    [[ -d $envpath/$e ]] || die "Not a valid environment name: '$e'"

    # Remove if requested
    if [[ $REMOVE -gt 0 ]]; then
        rname=$envpath/$e/.resource_types
        [[ -e $rname ]] && find $envpath/$e/.resource_types -delete
        [[ -e $rname ]] && {
            die "Unable to remove existing resource_type file '$rname'"
        }
    fi

    # Generate resource types
    set -x
    $PUPPET generate types --force --environment $e
    set +x
done
