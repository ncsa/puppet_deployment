#!/bin/bash

BASEPATH=/root/puppet_deployment
INCLUDES=( \
    $BASEPATH/common_funcs.sh
)
PUPPET=/opt/puppetlabs/bin/puppet
MODULES_PATH=/etc/puppetlabs/code/environments/production/modules

CONTROL_REPO_NAME=control_repo
CONFIG_VERSION_URL=https://raw.githubusercontent.com/voxpupuli/puppet-r10k/master/files/config_version.sh

HIERA_REPO_NAME=hiera


ENV_NAME=$( $PUPPET config print environment )
#ENV_PATH=$($PUPPET config print environmentpath)
#MODULE_DIR=$ENV_PATH/$ENV_NAME/modules
#MODULE_DIR=/etc/puppetlabs/code/environments/production/modules


for f in "${INCLUDES[@]}"; do
    [[ -f "$f" ]] || { echo "Cant include file '$f'"; exit 1
    }
    source  "$f"
done


###
# Populate control_repo
###

repopath=/root/"$CONTROL_REPO_NAME"
mkdir -p "$repopath"/{scripts,modules,local_modules,site}

#make Puppetfile
"$BASEPATH"/r10k/mk_puppetfile.sh -o "$repopath"/Puppetfile -e "$ENV_NAME"

#make environment config
>"$repopath"/environment.conf cat <<ENDHERE
modulepath = site:local_modules:modules
config_version = scripts/config_version.sh \$environment
ENDHERE

#make config_version.sh
curl -o "$repopath"/scripts/config_version.sh "$CONFIG_VERSION_URL"

#copy role and profile (modules) to site
for m in role profile; do
    src="$MODULES_PATH/$m"
    tgt="$repopath"/site
    rsync -rlpt "$src"/ "$tgt"/
done

#copy non-3rd party modules into local_modules
# TODO - merge mk_puppetfile.sh into this file to enable reuse of functions
# TODO - copy module directories
#        + Walk through list of module dirnames
#        + If dirname is "role" or "profile", skip
#        + If name from metadata.json is IN Puppetfile, skip
#        + rsync dir to local_modules

#create git repository & push to remote
# TODO - how to check for existing repo? 
# TODO - remove exising repo?

###
# Populate hiera repo
###

