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

PUPPET=/opt/puppetlabs/bin/puppet

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
LEGACY_REPO_NAME=legacy
while :; do
    case "$1" in
        -h|-\?|--help)
            echo "Usage: ${0##*/} [OPTIONS]"
            echo "Options:"
            echo "    -C CONTROL_REPO_NAME (default: '$CONTROL_REPO_NAME')"
            echo "    -d                   (enable debug mode)"
            echo "    -D HIERA_DATA_PATH   (default: '$HIERA_DATA_PATH')"
            echo "    -G GIT_URL_BASE      (default: '$GIT_URL_BASE')"
            echo "    -H HIERA_REPO_NAME   (default: '$HIERA_REPO_NAME')"
            echo "    -L LEGACY_REPO_NAME  (default: '$LEGACY_REPO_NAME')"
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
        -G)
            GIT_URL_BASE=$2
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


check_or_install_jq() {
    log "enter..."
    which jq &>/dev/null \
    || continue_or_exit "required program 'jq' not found; shall I install it?"
    local url='https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64'
    local tgt='/usr/local/bin/jq'
    curl -sfL -o "$tgt" "$url"
    local rc=$?
    [[ $rc -ne 0 ]] && die "curl returned non-zero '$rc'"
    chmod +x "$tgt"
}

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
    local controlrepo="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    local pupfn="$controlrepo"/Puppetfile
    public_module_names_versions \
    | sort \
    | awk "{ printf(\"mod '%s', '%s'\\n\", \$1, \$2) }" \
    >"$pupfn"
    # Fix for globus connect server
    sed -i '/erbc-globus/d' "$pupfn"
    # Fix for maestrodev-wget
    sed -i "/maestrodev-wget/c\mod 'puppet-wget', '2.0.0'" "$pupfn"
}


add_git_submodules_to_puppetfile() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local controlrepo="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    local pupfn="$controlrepo"/Puppetfile
    local prodpath="$( dirname $MODULES_PATH )"
    local fn_gitmodules="$( readlink -e $prodpath/.gitmodules )"
    local dn_git_submodules="$( readlink -e $prodpath/.git/modules )"
    [[ -f "$fn_gitmodules" ]] || return
	git config -lf "$fn_gitmodules" \
	| awk -F '.'  -v "dn_git_submodules=$dn_git_submodules" "
	function get_commit( name ) {
		fn_head = dn_git_submodules \"/\" name \"/HEAD\"
		cmd = \"cat \" fn_head
		cmd | getline commit
		return commit
	}
	\$3~/path=/ { n=split(\$NF,parts,/=/)
				  path=parts[n]
				  n=split(path,parts,/\\//)
				  name=parts[n]
				  commit = get_commit( path )
				  next
				}
	\$3~/url=/  { n=split(\$0,parts,/=/)
				  url=parts[n]
				  format = \"mod '%s',\\n    :git => '%s',\\n    :commit => '%s'\\n\"
				  printf(format, name, url, commit)
				}
" >> "$pupfn"
}


mk_environment_conf() {
    #make environment config
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    >"$repopath"/environment.conf cat <<ENDHERE
modulepath = site:modules:legacy
config_version = scripts/config_version.sh \$environment
ENDHERE
}


mk_hiera_conf() {
    #make hiera config
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    local hiera_orig=$($PUPPET config print hiera_config)
    local awk_cmd='/^  datadir: / {print "  datadir: data"; next} {print}'
    >"$repopath"/hiera.yaml awk "$awk_cmd" "$hiera_orig"
}


mk_config_version() {
    #get puppt config_version script
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local repopath="$OUTPUT_PATH/$CONTROL_REPO_NAME"
    local tgtfn="$repopath"/scripts/config_version.sh
    local tmpfn=$(mktemp)
    curl -sSo "$tmpfn" "$CONFIG_VERSION_URL" \
    || die "download failed for config_version.sh"
    sed -e "1 a \#\n\#\n\# Copied from: $CONFIG_VERSION_URL\n\n" "$tmpfn" > $tgtfn
    rm $tmpfn
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


commit_repo() {
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local reponame="$1"
    local default_branch=production
    [[ $# -ge 2 ]] && default_branch="$2"
    local repopath="$OUTPUT_PATH/$reponame"
    local remote_url="$GIT_URL_BASE/$reponame".git
    [[ -d "$repopath" ]] || die "Repopath '$repopath' directory not found"
    # fail if remote repo already exists
    git ls-remote -h "$remote_url" &>/dev/null
    local rc=$?
    [[ "$rc" -eq 0 ]] && die "Remote git repo already exists: '$remote_url'"
    # git returns something less than 128 if there is a different error (ie: access denied, etc.)
    [[ "$rc" -ne 128 ]] && die "Unknown error checking for existence or remote repo: '$remote_url'"
    (
        cd "$repopath"
        git init
        git checkout -b "$default_branch"
        git remote add origin "$remote_url"
        git add .
        git commit -m 'Initial commit'
        git push -u origin "$default_branch"
    ) || die "Failed to commit repo: '$reponame'"
}


mk_legacy_repo_skeleton() {
    log "enter..."
    [[ $DEBUG -gt 0 ]] && set -x
    local repopath="$OUTPUT_PATH/$LEGACY_REPO_NAME"
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


cp_legacy_modules() {
    # Copy non-3rd party modules into separate repo
    log "enter..."
    [[ "$DEBUG" -eq 1 ]] && set -x
    local site="$OUTPUT_PATH/$CONTROL_REPO_NAME/site"
    local legacyrepo="$OUTPUT_PATH/$LEGACY_REPO_NAME"
    local pupfn="$OUTPUT_PATH/$CONTROL_REPO_NAME/Puppetfile"
    local external_name metafn rc
    # walk through list of module dirnames
    find "$MODULES_PATH" -maxdepth 1 -mindepth 1 -type d -print \
    | while read dirpath; do
        metafn="$dirpath"/metadata.json
        if [[ "${dirpath##*/}" == "gpfs" ]] ; then
            # skip gpfs
            :
        elif [[ "${dirpath##*/}" == "role" ]] ; then
            # role goes into site
            cpdir "$dirpath" "$site"
        elif [[ "${dirpath##*/}" == "profile" ]] ; then
            # profile goes into site
            cpdir "$dirpath" "$site"
        elif [[ ! -f "$metafn" ]] ; then
            # if no metadata, assume it's a local module
            cpdir "$dirpath" "$legacyrepo"
        else
            # if name from metadata.json is IN Puppetfile, skip
            external_name=$( jq -r '.name' "$metafn" )
            grep -F "$external_name" "$pupfn" 1>/dev/null
            rc=$?
            case $rc in
                #0) continue;; #grep found a positive match, skip this module
                1) cpdir "$dirpath" "$legacyrepo" ;;
                2) die "during grep for '$external_name' in Puppetfile '$pupfn'"
            esac
        fi
    done
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


[[ "$DEBUG" -eq 1 ]] && set -x


###
# Check dependencies
###
check_or_install_jq


###
# Populate control repo
###
mk_control_repo_skeleton
mk_puppetfile
add_git_submodules_to_puppetfile
mk_environment_conf
mk_hiera_conf
mk_config_version

###
#  Populate legacy repo
###
mk_legacy_repo_skeleton
cp_legacy_modules

###
# Populate hiera repo
###
mk_hiera_repo_skeleton
cp_hieradata

###
#  Commit the new repos
###
commit_repo "$CONTROL_REPO_NAME"
commit_repo "$LEGACY_REPO_NAME"
commit_repo "$HIERA_REPO_NAME"
