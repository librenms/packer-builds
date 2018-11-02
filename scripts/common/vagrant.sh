#!/bin/sh

set -e
set -x

date | sudo tee /etc/vagrant_box_build_time

mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh/
chmod 600 ~/.ssh/authorized_keys
