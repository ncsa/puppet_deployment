#!/bin/bash

URL_BASE=https://dl.gitea.io/gitea/
VERSION=1.5.0
URL_BIN=$URL_BASE/$VERSION/gitea-${VERSION}-linux-amd64
URL_ASC=${URL_BIN}.asc
GITEA=/usr/local/bin/gitea
INSTALL_BASE=/var/lib/gitea
TMPDIR=$(mktemp -d)


cleanup() {
    find $TMPDIR -delete
}


die() {
    echo "ERROR: $*" 1>&2
    cleanup
    exit 1
}

install() {
    [[ -f $GITEA ]] && return 0
    curl -s -o $TMPDIR/gitea $URL_BIN
    curl -s -o $TMPDIR/asc $URL_ASC
    gpg --keyserver pgp.mit.edu --recv 0x2D9AE806EC1592E2
    gpg --verify $TMPDIR/asc $TMPDIR/gitea || die "gpg verify failed"
    cp $TMPDIR/gitea $GITEA
    chown git:git $GITEA
    chmod 110 $GITEA
}


prep_fs() {
    [[ -d $INSTALL_BASE/ ]] && return 0
	adduser \
	   --system \
	   --shell /bin/bash \
	   --comment 'Git Version Control' \
	   --user-group \
       --home-dir /home/git \
       --create-home \
	   git
    mkdir -p $INSTALL_BASE/{custom,data,indexers,public,log}
    chown git:git $INSTALL_BASE/{data,indexers,log}
    chmod 750 $INSTALL_BASE/{data,indexers,log}
    mkdir -p /etc/gitea
    chown root:git /etc/gitea
    chmod 750 /etc/gitea
}


configure() {
    local inifn=/etc/gitea/app.ini
    [[ -f $inifn ]] && return 0
#APP_DATA_PATH = $INSTALL_BASE
#DOMAIN = $( hostname -I | xargs -n1 echo | grep 192.168 )
    >$inifn cat <<ENDHERE
[server]
START_SSH_SERVER = true
SSH_PORT = 3022
[database]
DB_TYPE = sqlite3
PATH = $INSTALL_BASE/data/gitea.db
LOG_SQL = false
[security]
INSTALL_LOCK = true
SECRET_KEY = $( $GITEA generate secret SECRET_KEY )
INTERNAL_TOKEN = $( $GITEA generate secret INTERNAL_TOKEN )
[log]
MODE = console, file
ENDHERE
    chmod 644 $inifn
    curl \
        -s \
        -o ${inifn}.sample \
        https://raw.githubusercontent.com/go-gitea/gitea/master/custom/conf/app.ini.sample
    chmod 444 ${inifn}.sample
}


mk_service() {
    local url=https://raw.githubusercontent.com/go-gitea/gitea/master/contrib/systemd/gitea.service
    local tgt=/etc/systemd/system/gitea.service
    [[ -f $tgt ]] && return 0
    curl -s -o $tgt $url
    #systemctl enable gitea
    #systemctl start gitea
}


uninstall() {
    find $INSTALL_BASE -delete
    find /etc -name 'gitea*' -delete
    find /etc/gitea -delete
    rm -f $GITEA &>/dev/null
    userdel -r git
}


###
# Process Command Line
###
FORCE=0
while :; do
    case "$1" in
        -f) FORCE=1
            ;;
        -h|-\?|--help)
            echo "Usage: ${0##*/} [OPTIONS]"
            echo "Options:"
            echo "    -f        (force install; clean existing install; then run install steps"
            exit
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

set -x

[[ $FORCE -eq 1 ]] && uninstall

prep_fs
install
configure
mk_service

cleanup
