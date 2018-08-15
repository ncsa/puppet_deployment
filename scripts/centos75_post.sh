#!/bin/bash

PKGLIST=( \
  bind-utils \
  git \
  iproute \
  less \
  lsof \
  lvm2 \
  tree \
  vim \
  which \
  python36-tools
)

PYTHON_PKGLIST=( \
  pip \
  pyyaml
)

set -x

# Ensure EPEL repo is installed
yum -y install epel-release

# Install packages
yum -y install "${PKGLIST[@]}"

# Setup Python3
python36 -m ensurepip
python36 -m pip install -U "${PYTHON_PKGLIST[@]}"
