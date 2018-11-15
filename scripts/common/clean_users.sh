#!/bin/sh

set -e
set -x

sudo bash -c 'cat <<EOF > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty
vagrant ALL=(ALL) NOPASSWD: ALL
EOF'

sudo chmod 440 /etc/sudoers.d/vagrant
