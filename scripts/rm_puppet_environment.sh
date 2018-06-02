#!/bin/bash

set -x
ls -d /etc/puppetlabs/code/environments/* \
| grep -v 'production\|test' \
| xargs -r -n1 -I{} find {} -delete
