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


function image_exists() {
    [[ $DEBUG -eq 1 ]] && set -x
    # return 0 if one or more images exist matching passed in crieria
    # PARAMS
    #   name - String (Required) - imagename
    #   filter - String (Optional) - one or more filter strings
    [[ $# -ge 2 ]] || croak 'Got $# params, expected 2 or more'
    local name="$1"
    shift
    count=$( docker_search image "reference=$name" $* | wc -l )
    [[ $count -gt 0 ]]
}


function container_exists() {
    [[ $DEBUG -eq 1 ]] && set -x
    # return 0 if one or more containers exist that match criteria
    # PARAMS
    #   name - String (Required) - containername
    #   filter - String (Optional) - one or more filter strings
    local name="$1"
    shift
    count=$( docker_search container "name=$name" $* | wc -l )
    [[ $count -gt 0 ]]
}


function rm_images() {
    [[ $DEBUG -eq 1 ]] && set -x
    # Remove all images found matching the filter parameters
    # PARAMS
    #   filter - String (Required) - one or more filter strings
    # TODO - need to sort output by CREATED order in newest first order
    docker_search images $* \
    | sort -u \
    | xargs -r -n1 docker inspect --format '{{.Created}} {{.ID}}' \
    | sort -r \
    | awk '{print $2}' \
    | xargs -r docker rmi -f
    [[ $( docker_search images $* | wc -l ) -gt 0 ]] \
    && croak "Unable to remove all images"
}


function rm_containers() {
    [[ $DEBUG -eq 1 ]] && set -x
    # Remove all containers found matching the filter parameters
    # PARAMS
    #   filter - String (Required) - one or more filter strings
    docker_search containers $* \
    | xargs -r docker stop \
    | xargs -r docker rm
    [[ $( docker_search containers $* | wc -l ) -gt 0 ]] \
    && croak "Unable to remove all containers"
}


function docker_search() {
    [[ $DEBUG -eq 1 ]] && set -x
    # Search for docker "thing" IDs
    # PARAMS
    #   type
    #   - String (Required) - The type of docker "thing" to search
    #                         (ie: images, containers, etc.)
    #   filter
    #   - String (Required) - one or more filter strings
    [[ $# -ge 2 ]] || croak 'Got $# params, expected 2 or more'
    local kindofthing=$1
    shift
    local filters=()
    local subcmd
    case "$kindofthing" in
        image*)
            subcmd=images
            ;;
        container* | ps)
            subcmd=ps
            ;;
        *)
            croak "Unhandled docker \"thing\": '$kindofthing'"
            ;;
    esac
    for f; do
        filters+=( '-f' "$f" )
    done
    [[ ${#filters[*]} -gt 0 ]] || croak 'Got 0 filters, at least 1 filter is required'
    docker $subcmd -a -q "${filters[@]}"
}
