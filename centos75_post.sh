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

# Ensure EPEL repo is installed
yum -y install epel

# Install packages
yum -y install

# Setup Python3
python36 -m ensurepip
python36 -m pip install -U pip pyyaml
