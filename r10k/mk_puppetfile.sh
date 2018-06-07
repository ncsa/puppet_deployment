#!/bin/bash

BASE=/root/puppet_deployment
INCLUDES=( \
    $BASE/common_funcs.sh
)
MODULE_DIR=/etc/puppetlabs/code/environments/production/modules
OUTFILE=Puppetfile

for f in "${INCLUDES[@]}"; do
    [[ -f "$f" ]] || { echo "Cant include file '$f'"; exit 1
    }
    source  "$f"
done


get_public_module_info() {
    # Find 3rd party modules
    do_jq '
    select( .source | contains("github.com") ) 
    | [.name, .version] 
    | @tsv
    '
}


get_dependencies() {
    # Get all dependencies
    do_jq '
    .dependencies
    | select( (. | length) > 0 )
    | .[]
    | [.name, .version_requirement]
    | @tsv
    '
}


do_jq() {
    [[ -d "$MODULE_DIR" ]] || die "cant find module dir '$MODULE_DIR'"
    find $MODULE_DIR -name metadata.json \
    | grep -v gpfs \
    | xargs -r -n1 /root/jq -r "$1"
}


mk_Puppetfile() {
    # Take list of "name" "version" lines and write a Puppetfile
    awk "{ printf(\"mod '%s', '%s'\\n\", \$1, \$2) }"
}


# Process cmdline options
while getopts ":m:o:vd" opt; do
    case $opt in
        m)
            MODULE_DIR=$OPTARG
            ;;
        o)
            OUTFILE=$OPTARG
            ;;
        v)
            VERBOSE=1
            ;;
        d)
            VERBOSE=1
            DEBUG=1
            ;;
        \?)
            die "Invalid option: -$OPTARG"
            ;;
        :)
            die "Option -$OPTARG requires an argument."
            ;;
    esac
done
shift $((OPTIND-1))

# Check sources
[[ -d "$MODULE_DIR" ]] || die "cant find module dir: '$MODULE_DIR'"

# Get all 3rd party modules and their dependencies
get_public_module_info | sort | mk_Puppetfile >"$OUTFILE"
