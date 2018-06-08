#!/bin/bash

BASEPATH=/root/puppet_deployment
INCLUDES=( \
    $BASEPATH/common_funcs.sh
)
VERBOSE=0
DEBUG=0
ALWAYSYES=0

MODULES_PATH=/etc/puppetlabs/code/environments/production/modules
GIT_URL_BASE=git@git.ncsa.illinois.edu:lsst/puppet
OUTPUT_PATH=/root
CONTROL_REPO_NAME=control_repo
CONFIG_VERSION_URL=https://raw.githubusercontent.com/voxpupuli/puppet-r10k/master/files/config_version.sh
HIERA_REPO_NAME=hiera

for f in "${INCLUDES[@]}"; do
    [[ -f "$f" ]] || { echo "Cant include file '$f'"; exit 1
    }
    source  "$f"
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
            rsync_module "$dirpath" "$repopath"/site
            continue
        }
        # if name from metadata.json is IN Puppetfile, skip
        external_name=$( jq -r '.name' "$metafn" )
        pupfn="$repopath"/Puppetfile
        grep -F "$external_name" "$pupfn" 1>/dev/null
        rc=$?
        case $rc in
            0) continue;; #grep found a positive match, skip this module
            1) rsync_module "$dirpath" "$repopath"/site ;;
            2) die "during grep for '$external_name' in Puppetfile '$pupfn'"
        esac
    done
}


rsync_module() {
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


commit_control_repo() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    local remote_url="$GIT_URL_BASE/$CONTROL_REPO_NAME".git
    local rc
    # fail if remote repo doesn't exist
    git ls-remote -h "$remote_url" &>/dev/null
    rc=$?
    [[ "$rc" -ne 0 ]] && die "Remote git repo doesn't exist."
    (
        cd "$repopath"
        git init
        git checkout -b production
        git remote add origin "$remote_url"
        git add .
        git commit -m 'Initial commit'
        git push -u origin production
    )
    echo $(pwd)
}


###
# Process cmdline
###
# Process cmdline options
while getopts ":c:h:m:o:dvy" opt; do
    case $opt in
        c)
            CONTROL_REPO_NAME=$OPTARG
            ;;
        h)
            HIERA_REPO_NAME=$OPTARG
            ;;
        m)
            MODULES_PATH=$OPTARG
            ;;
        o)
            OUTPUT_PATH=$OPTARG
            ;;
        y)
            ALWAYSYES=1
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

[[ "$DEBUG" -eq 1 ]] && set -x


###
# Populate control_repo
###
#mk_control_repo_skeleton
#mk_puppetfile
#mk_environment_conf
#mk_config_version
#cp_local_modules
commit_control_repo

#create git repository & push to remote
# TODO - how to check for existing repo? 
# TODO - remove exising repo?

###
# Populate hiera repo
###

