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

# Global settings
PUPPET=/opt/puppetlabs/bin/puppet
PUPPETSERVER=/opt/puppetlabs/bin/puppetserver
HOSTNAME=$(hostname)
OS_NAME=el
OS_VER=7
REQUIRED_PKGS_COMMON=( bind-utils lsof )
REQUIRED_PKGS_MASTER=( PyYAML )
REQUIRED_PKGS_AGENT=()

# Command line option defaults
VERBOSE=0
DEBUG=0
FORCE="${PUPINSTALLFORCE:-0}"
BKUP_DIR="${PUPBKUPDIR:-/backups}"
BUILD_TYPE="$PUPBUILDTYPE"           #master | agent (allow to be set by env var)
#CONFIG_TYPE="$PUPCONFIGTYPE"         #new | restore | r10k (allow env var)
AGENT_CERTNAME="$PUPCERTNAME"        #allow override hostname
AGENT_PUPMASTER="$PUPMASTER"         #ip or valid DNS hostname of pupmaster
DNS_ALT_NAMES="$PUPCAALTNAMES"       #dns alt names for puppet certificate
PUP_VERSION="$PUPINSTALLVER"         #version of puppet to install (5 or 6)
AUTOSIGN_NAMES="$PUPAUTOSIGN"         #set autosign strings


###
# Process Command Line
###
while :; do
    case "$1" in
        -h|-\?|--help)
            echo "Usage: ${0##*/} [OPTIONS]"
            echo "Options:"
            echo "    -a                    (build an agent)"
            echo "    -A <AgentCertname>    (override certname, defaults to hostname)"
            echo "    -b <backup_dir>       (path to backup directory, containing *_puppet_config.tar.gz files)"
            echo "    -d                    (enable debug mode)"
            echo "    -D <dns_alt_names>    (Comma separated list of alternate names for puppet CA certificate)"
            echo "    -F                    (Force install. Install over the top of existing setup)"
            echo "    -m                    (build a master)"
#            echo "    -M <new|restore|r10k> (how to configure puppet master)"
            echo "    -P <Puppet Master IP> (IP or hostname of puppet master, used only for agent build type)"
            echo "    -u <autosign_names>   (comma separated list of autosign names)"
            echo "    -v                    (enable verbose mode)"
            echo "    -V <puppet version>   Version of puppet to install (ie: 5 or 6)"
            exit
            ;;
        -a) BUILD_TYPE=agent
            ;;
        -A) AGENT_CERTNAME="$2"
            shift
            ;;
        -b) BKUP_DIR="$2"
            shift
            ;;
        -d) VERBOSE=1
            DEBUG=1
            ;;
        -D) DNS_ALT_NAMES="$2"
            shift
            ;;
        -F) FORCE=1
            ;;
        -m) BUILD_TYPE=master
            ;;
#        -M) CONFIG_TYPE="$2"
#            shift
#            ;;
        -P) AGENT_PUPMASTER="$2"
            shift
            ;;
        -u) AUTOSIGN_NAMES="$2"
            shift
            ;;
        -v) VERBOSE=1
            ;;
        -V) PUP_VERSION="$2"
            shift
            ;;
        --) shift
            break
            ;;
        -?*)
            die "Invalid option: $1"
            ;;
        *)  break
            ;;
    esac
    shift
done



###
# Functions
###

assert_valid_build_type() {
    case "$BUILD_TYPE" in
        master)
#            # check config_type ... only relevant if build_type is MASTER
#            if [[ " new restore " =~ " $CONFIG_TYPE " ]]; then
#                : #pass
#            else
#                die "Missing or invalid config type: '$CONFIG_TYPE' for puppet master"
#            fi
            : #pass
            ;;
        agent)
            [[ -n "$AGENT_PUPMASTER" ]] || die 'Missing Pup Master IP or hostname'
            ;;
        *)
            die "Invalid build type '$BUILD_TYPE'"
            ;;
    esac
}


clean_old() {
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x
    [[ "$FORCE" -lt 1 ]] && return 0  # Do nothing if force is not set
    # remove puppet rpm packages
    yum list installed | awk '/puppet/ {print $1}' \
    | xargs -r yum -y remove
    # delete puppet install locations
    find /etc/puppetlabs -delete
    find /opt/puppetlabs -delete
    find /var/cache/r10k -delete
    find /etc/yum.repos.d/ -type f -name 'puppet*' -delete
}


install_required_pkgs() {
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x
    local pkg_list=( "${REQUIRED_PKGS_COMMON[@]}" )
    case "$BUILD_TYPE" in
        master)
            pkg_list+=( "${REQUIRED_PKGS_MASTER[@]}" )
            ;;
        agent)
            pkg_list+=( "${REQUIRED_PKGS_AGENT[@]}" )
            ;;
    esac
    [[ ${#pkg_list[@]} -gt 0 ]] || die "empty pkg list"
    install_pkgs "${pkg_list[@]}" || die "error during pkg install"
}


install_puppet() {
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x
    #Install yum repo
    local YUM_REPO_URL=https://yum.puppet.com
    case "$PUP_VERSION" in
        5|6)
            local rpm_fn=puppet${PUP_VERSION}-release-${OS_NAME}-${OS_VER}.noarch.rpm
            local path=puppet${PUP_VERSION}
            YUM_REPO_URL=$YUM_REPO_URL/$path/$rpm_fn
            ;;
        *)
            die "Unknown puppet version: '$PUP_VERSION'"
            ;;
    esac
    ls /etc/yum.repos.d/puppet*.repo &>/dev/null \
    || yum -y install $YUM_REPO_URL
    ls /etc/yum.repos.d/puppet*.repo &>/dev/null \
    || die "Failed to install Yum repo file"

    #Install packages
    local pkglist
    case "$BUILD_TYPE" in
        master)
            pkglist=( puppetserver )
            ;;
        agent)
            pkglist=( puppet-agent )
            ;;
    esac
    yum -y install "${pkglist[@]}"
}


get_bkup_src() {
    ls -t $BKUP_DIR/*_puppet_config.tar.gz | head -1
}


#restore_config() {
#    log "enter..."
#    [[ "$DEBUG" -gt 0 ]] && set -x
#    local fn=$( get_bkup_src )
#    [[ -z "$fn" ]] && die "Cant find a puppet backup"
#    tar zxPf "$fn" --overwrite -T - <<ENDHERE
#/etc/puppetlabs/puppet/*.conf
#/etc/puppetlabs/puppet/*.yaml
#/etc/puppetlabs/puppetserver/
#/etc/puppetlabs/code/config/
#ENDHERE
#}


#disable_puppetdb() {
#    log "enter..."
#    [[ "$DEBUG" -gt 0 ]] && set -x
#    $PUPPET config set storeconfigs false --section master
#    $PUPPET config set reports store --section master
#    for f in puppetdb.conf routes.yaml; do
#        rm /etc/puppetlabs/puppet/"$f"
#    done
#}


#restore_environments() {
#    log "enter..."
#    [[ "$DEBUG" -gt 0 ]] && set -x
#    fn=$( get_bkup_src )
#    [[ -z "$fn" ]] && die "Cant find a puppet backup"
#    find /etc/puppetlabs/code/environments -delete
#    tar zxPf "$fn" --overwrite -T - <<ENDHERE
#/etc/puppetlabs/code/environments
#ENDHERE
#}


#restore_ca() {
#    log "enter..."
#    [[ "$DEBUG" -gt 0 ]] && set -x
#    local fn=$( get_bkup_src )
#    [[ -z "$fn" ]] && die "Cant find a puppet backup"
#    tar zxPf "$fn" --overwrite -T - <<ENDHERE
#/etc/puppetlabs/puppet/ssl
#ENDHERE
#}


configure_ca() {
    # For puppet6, see: https://puppet.com/docs/puppet/6.0/ssl_regenerate_certificates.html
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x

    # Setup Alt Names
    local ip_alts alt_names
    if [[ $PUP_VERSION == 6 ]] ; then
        ip_alts=( $( for i in $(hostname -I); do echo "IP:$i"; done ) )
    else
        ip_alts=( $(hostname -I) )
    fi
    alt_names=$( echo "${ip_alts[@]} $DNS_ALT_NAMES" \
        | sed -e 's/^[ \t]*//;s/[ \t]*$//' \
        | sed -e 's/ /,/g'
        )

    $PUPPET config set dns_alt_names "$alt_names"
}


puppetserver() {
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x
    [[ "$BUILD_TYPE" != 'master' ]] && {
        log "nothing to do for build_type: '$BUILD_TYPE'"
        return 0
    }
    #local pupsrvc="$PUPPET resource service puppetserver"
    local action=$1
    case $action in
        *start|reload) 
                #$pupsrvc ensure=running
                $PUPPETSERVER $action
                is_puppetserver_running || die 'puppetserver not running'
                ;;
        stop)
                #$pupsrvc ensure=stopped
                $PUPPETSERVER $action
                is_puppetserver_running && die 'puppetserver still running'
                ;;
        *)
                die "unknown action '$action'"
    esac
}


is_puppetserver_running() {
    [[ "$DEBUG" -gt 0 ]] && set -x
    log "enter..."
    lsof -i :8140 &>/dev/null
}


create_autosign() {
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x
    local fn=$( $PUPPET config print autosign )
    [[ -f $fn ]] && return 0
    local parts=( ${AUTOSIGN_NAMES//,/ } )
    for l in "${parts[@]}"; do echo "$l"; done >$fn
}


agent_config() {
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x
    $PUPPET config set server "$AGENT_PUPMASTER"
    [[ -n "$AGENT_CERTNAME" ]] && $PUPPET config set certname "$AGENT_CERTNAME"
}


agent_run() {
    log "enter..."
    [[ "$DEBUG" -gt 0 ]] && set -x
    $PUPPET agent --test
}


####################################################


# Always perform these steps
assert_root
assert_valid_build_type
clean_old
install_required_pkgs
install_puppet

# Next steps depend on install type
case "$BUILD_TYPE" in
    master)
#        case "$CONFIG_TYPE" in
#            restore)
#                restore_config
#                disable_puppetdb
#                restore_environments
#                restore_ca
#                ;;
#            new)
#                configure_ca
#                create_autosign
#                ;;
#        esac
        configure_ca
        create_autosign
        #puppetserver start
        #is_puppetserver_running
        ;;
    agent)
        agent_config
        #agent_run
        ;;
esac

