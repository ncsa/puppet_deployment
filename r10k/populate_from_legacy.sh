#!/bin/bash

BASEPATH=/root/puppet_deployment
INCLUDES=( \
    $BASEPATH/common_funcs.sh
)

for f in "${INCLUDES[@]}"; do
    [[ -f "$f" ]] || { echo "Cant include file '$f'"; exit 1
    }
    source  "$f"
done


###
# Process cmdline
###
VERBOSE=0
DEBUG=0
ALWAYSYES=0
MODULES_PATH=/etc/puppetlabs/code/environments/production/modules
HIERA_DATA_PATH=/etc/puppetlabs/code/environments/production/hieradata
GIT_URL_BASE=git@git.ncsa.illinois.edu:lsst/puppet
CONFIG_VERSION_URL=https://raw.githubusercontent.com/voxpupuli/puppet-r10k/master/files/config_version.sh
OUTPUT_PATH=/root
CONTROL_REPO_NAME=control
HIERA_REPO_NAME=hiera
while :; do
    case "$1" in
        -h|-\?|--help)
            echo "Usage: ${0##*/} [OPTIONS]"
            echo "Options:"
            echo "    -C CONTROL_REPO_NAME (default: '$CONTROL_REPO_NAME')"
            echo "    -d                   (enable debug mode)"
            echo "    -D HIERA_DATA_PATH   (default: '$HIERA_DATA_PATH')"
            echo "    -H HIERA_REPO_NAME   (default: '$HIERA_REPO_NAME')"
            echo "    -M MODULES_PATH      (default: '$MODULES_PATH')"
            echo "    -O OUTPUT_PATH       (default: '$OUTPUT_PATH')"
            echo "    -v                   (enable verbose mode)"
            echo "    -y                   (answer YES to questions ... ie: delete local output dirs)"
            exit
            ;;
        -C)
            CONTROL_REPO_NAME=$2
            shift
            ;;
        -d)
            VERBOSE=1
            DEBUG=1
            ;;
        -D)
            HIERA_DATA_PATH=$2
            shift
            ;;
        -H)
            HIERA_REPO_NAME=$2
            shift
            ;;
        -M)
            MODULES_PATH=$2
            shift
            ;;
        -O)
            OUTPUT_PATH=$2
            shift
            ;;
        -v)
            VERBOSE=1
            ;;
        -y)
            ALWAYSYES=1
            ;;
        --)
            shift
            break
            ;;
        -?*)
            die "Invalid option: -$1"
            ;;
        *)
            break
            ;;
    esac
    shift
done


###
# Functions
###


public_module_names_versions() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    do_jq '
    select( .source | contains("github.com") )
    | [.name, .version]
    | @tsv
    '
}


do_jq() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    [[ -d "$MODULES_PATH" ]] || die "cant find module dir '$MODULES_PATH'"
    find $MODULES_PATH -name metadata.json \
    | grep -v gpfs \
    | xargs -r -n1 jq -r "$1"
}


mk_control_repo_skeleton() {
    log "enter..."
    [[ $DEBUG -gt 0 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    if [[ -d "$repopath" ]] ; then
        if [[ "$ALWAYSYES" -eq 1 ]] ; then
            : #pass
        elif ask_yes_no "Directory exists, ok to delete: ['$repopath'] ?" ; then
            : #pass
        else
            die "Directory exists: ['$repopath']"
        fi
        find "$repopath" -delete
    fi
    mkdir -p "$repopath"/{scripts,site,modules}
}


mk_puppetfile() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    puppetfile_path="$repopath"/Puppetfile
    public_module_names_versions \
    | sort \
    | awk "{ printf(\"mod '%s', '%s'\\n\", \$1, \$2) }" \
    >"$puppetfile_path"
}


mk_environment_conf() {
    #make environment config
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    >"$repopath"/environment.conf cat <<ENDHERE
modulepath = site:modules
config_version = scripts/config_version.sh \$environment
ENDHERE
}


mk_hiera_conf() {
    #make hiera config
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    >"$repopath"/hiera.yaml cat <<ENDHERE
---
version: 5
defaults:
    datadir: data
    data_hash: yaml_data
ENDHERE
}



mk_config_version() {
    #get puppt config_version script
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    curl -sSo "$repopath"/scripts/config_version.sh "$CONFIG_VERSION_URL" \
    || die "download failed for config_version.sh"
}


cp_local_modules() {
    # Copy non-3rd party modules into site
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    local external_name metafn pupfn rc
    # walk through list of module dirnames
    find "$MODULES_PATH" -maxdepth 1 -mindepth 1 -type d -print \
    | while read dirpath; do
        # skip gpfs, do it manually at the end
        [[ "${dirpath##*/}" == "gpfs" ]] && continue
        metafn="$dirpath"/metadata.json
        # if no metadata, assume it's a local module
        [[ -f "$metafn" ]] || {
            cpdir "$dirpath" "$repopath"/site/
            continue
        }
        # if name from metadata.json is IN Puppetfile, skip
        external_name=$( jq -r '.name' "$metafn" )
        pupfn="$repopath"/Puppetfile
        grep -F "$external_name" "$pupfn" 1>/dev/null
        rc=$?
        case $rc in
            0) continue;; #grep found a positive match, skip this module
            1) cpdir "$dirpath" "$repopath"/site/ ;;
            2) die "during grep for '$external_name' in Puppetfile '$pupfn'"
        esac
    done
}


cpdir() {
    # Copy module directory to target location
    # PARAMS:
    #   src : String : path to module directory
    #   tgt : String : path to target parent directory
    [[ "$DEBUG" -eq 1 ]] && set -x
    local src="$1"
    local tgt="$2"
    [[ -d "$src" ]] || die "Directory not found: '$src'"
    [[ -d "$tgt" ]] || die "Directory not found: '$tgt'"
    log "rsync -rlpt '$src' '$tgt'/"
    rsync -rlpt "$src" "$tgt"/
}


_commit_repo() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$1"
    local remote_url="$2"
    [[ -d "$repopath" ]] || die "Repopath '$repopath' directory not found"
    local rc
    # fail if remote repo doesn't exist
    git ls-remote -h "$remote_url" &>/dev/null
    rc=$?
    [[ "$rc" -ne 0 ]] && die "Remote git repo doesnt exist: '$remote_url'"
    (
        cd "$repopath"
        git init
        git checkout -b production
        git remote add origin "$remote_url"
        git add .
        git commit -m 'Initial commit'
        git push -u origin production
    )
}


commit_control_repo() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    local remote_url="$GIT_URL_BASE/$CONTROL_REPO_NAME".git
    _commit_repo "$repopath" "$remote_url" \
    || die "Failed to commit control repo"
}


mk_hiera_repo_skeleton() {
    log "enter..."
    [[ $DEBUG -gt 0 ]] && set -x
    local repopath="$OUTPUT_PATH/$HIERA_REPO_NAME"
    if [[ -d "$repopath" ]] ; then
        if [[ "$ALWAYSYES" -eq 1 ]] ; then
            : #pass
        elif ask_yes_no "Directory exists, ok to delete: ['$repopath'] ?" ; then
            : #pass
        else
            die "Directory exists: ['$repopath']"
        fi
        find "$repopath" -delete
    fi
    mkdir -p "$repopath"
}


cp_hieradata() {
    # Copy legacy hieradata into unique hiera repo
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    [[ -d "$HIERA_DATA_PATH" ]] || die "Hiera data path '$HIERA_DATA_PATH' doesnt exist"
    local repopath="$OUTPUT_PATH/$HIERA_REPO_NAME"
    [[ -d "$repopath" ]] || die "Hiera repo dir '$repodir' doesnt exist"
    cpdir "$HIERA_DATA_PATH"/ "$repopath" \
    || die "failed to copy hieradata from '$HIERA_DATA_PATH' to '$repopath'"
}


commit_hiera_repo() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$HIERA_REPO_NAME"
    local remote_url="$GIT_URL_BASE/$HIERA_REPO_NAME".git
    _commit_repo "$repopath" "$remote_url" \
    || die "Failed to commit hiera repo"
}

[[ "$DEBUG" -eq 1 ]] && set -x


###
# Check dependencies
###
which jq &>/dev/null || die "required program 'jq' not found"


###
# Populate control_repo
###
mk_control_repo_skeleton
mk_puppetfile
mk_environment_conf
mk_hiera_conf
mk_config_version
cp_local_modules
commit_control_repo

###
# Populate hiera repo
###
mk_hiera_repo_skeleton
cp_hieradata
commit_hiera_repo
