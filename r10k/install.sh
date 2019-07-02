#!/bin/bash

BASE=/root/puppet_deployment
MANIFEST=$BASE/$MODULE_NAME/manifest.pp
BIN=/opt/puppetlabs/puppet/bin
PUPPET=${BIN}/puppet
GEM=${BIN}/gem
SSH_PRIVATE_KEY=/etc/puppetlabs/r10k/ssh/id_ed25519
COMMON=$BASE/common_funcs.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"


# Command line option defaults
DEBUG=0
MK_SSH_KEY=0
VERBOSE=0

###
# Process Command Line
###
while :; do
    case "$1" in
        -d) VERBOSE=1
            DEBUG=1
            ;;
        -h|-\?|--help)
            echo "Usage: ${0##*/} [OPTIONS]"
            echo "Options:"
            echo "    -d                  (enable debug mode)"
            echo "    -g <GITSERVER>      (git server host) [Default: None]"
            echo "    -k                  (mk new ssh private key) [Default: No]"
            echo "    -K <SSH_key_path>   (directory for r10k ssh keys)"
            echo "                        [Default: ${SSH_PRIVATE_KEY}]"
            echo "    -v                  (enable verbose mode)"
            exit
            ;;
        -g) GITSERVER="$2"
            shift
            ;;
        -k) MK_SSH_KEY=1
            ;;
        -K) SSH_PRIVATE_KEY="$2"
            shift
            ;;
        -v) VERBOSE=1
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

# Check that cmdline options make sense
if [[ "${#GITSERVER}" -lt 1 ]] ; then
    die "GITSERVER cannot be empty"
fi

prerun() {
    log "Remove unused (default) global hiera.yaml"
    rm -f /etc/puppetlabs/puppet/hiera.yaml
}


install() {
    [[ -f $BIN/r10k ]] && return
    log "Install r10k"
    $GEM install r10k
    log "Make symlinks"
    ln -s $BIN/r10k /opt/puppetlabs/bin
#    log "Install development tools"
#    yum -y group install 'Development Tools'
#    log "Install dependencies for rugged"
#    yum -y install cmake libssh2-devel openssl-devel python-pthreading
#    log "Install rugged"
#    $GEM install rugged
}


configure() {
    confdir=/etc/puppetlabs/r10k
    srcfn=$BASE/r10k/r10k.tmpl.yaml
    tgtfn=$confdir/r10k.yaml
    log "Create r10k config: '$tgtfn'"
    mkdir -p $confdir
    codedir=$( $PUPPET config print codedir )
    sed -e "s?___CODEDIR___?$codedir?" \
        -e "s?___GITSERVER___?$GITSERVER?" \
        $srcfn >$tgtfn
}


mk_ssh_key() {
    [[ ${MK_SSH_KEY} -lt 1 ]] && return
    [[ -f $SSH_PRIVATE_KEY ]] && return
    log "Make gitlab deployment key"
    mkdir -p $( dirname "$SSH_PRIVATE_KEY" )
    ssh-keygen -t ed25519 -f "$SSH_PRIVATE_KEY" -N "" -C "r10k@$(hostname -f)"
    chmod 0400 "$SSH_PRIVATE_KEY" "${SSH_PRIVATE_KEY}.pub"

    echo "On your git server, add public key (below) as a deploy key for all repos listed in 'r10k.yaml'"
    echo "New Deploy Public Key ..."
    cat "${SSH_PRIVATE_KEY}.pub"
    echo
    echo
    echo "Ensure '/root/.ssh/config' is setup to use the SSH private key for access to git..."
    echo "..."
    cat <<ENDHERE
Host ${GITSERVER}
    User git
    PreferredAuthentications publickey
    IdentityFile ${SSH_PRIVATE_KEY}
    ForwardX11 no
ENDHERE
	echo "..."
	echo
}


postrun() {
    known_hosts=$HOME/.ssh/known_hosts
    grep -qv "$GITSERVER" $known_hosts \
    || ssh-keyscan -4 "$GITSERVER" >> $known_hosts
}

#set -x

prerun

install

configure

mk_ssh_key

postrun
