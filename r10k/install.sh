#!/bin/bash

BASE=/root/puppet_deployment
MANIFEST=$BASE/$MODULE_NAME/manifest.pp
BIN=/opt/puppetlabs/puppet/bin
PUPPET=${BIN}/puppet
GEM=${BIN}/gem
SSH_PRIVATE_KEY=/etc/puppetlabs/r10k/ssh/id_ecdsa
COMMON=$BASE/common_funcs.sh

[[ -f "$COMMON" ]] || {
    echo "Fatal: unable to source '$COMMON'" >&2
    exit 1
}
source "$COMMON"


prerun() {
    log "Remove unused (default) global hiera.yaml"
    rm -f /etc/puppetlabs/puppet/hiera.yaml
}


install() {
    log "Install r10k"
    $GEM install r10k
    log "Make symlinks"
    ln -s $BIN/r10k /opt/puppetlabs/bin
#    log "Install dependencies for rugged"
#    yum -y group install 'Development Tools'
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
        -e "s?___SSH_PRIVATE_KEY___?$SSH_PRIVATE_KEY?" \
        $srcfn >$tgtfn
}


mk_ssh_key() {
    [[ -f $SSH_PRIVATE_KEY ]] && return
    log "Make gitlab deployment key"
    mkdir -p $( dirname $SSH_PRIVATE_KEY )
    ssh-keygen -t ecdsa -b 521 -f $SSH_PRIVATE_KEY -N ""
    echo "New Deploy Public Key ..."
    cat ${SSH_PRIVATE_KEY}.pub
}


postrun() {
    echo "On your git server, add public key '${SSH_PRIVATE_KEY}.pub' as a deploy key for all repos listed in 'r10k.yaml'"
    echo
    echo "Ensure '/root/.ssh/config' is setup to use the SSH private key for access to git..."
    echo "..."
    cat <<ENDHERE
Host 10.142.181.4
    User git
    PreferredAuthentications publickey
    IdentityFile ${SSH_PRIVATE_KEY}
    ForwardX11 no
ENDHERE
	echo "..."
	echo
}

#set -x

prerun

install

configure

mk_ssh_key

postrun
