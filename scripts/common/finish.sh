#!/bin/sh

set -e
set -x

# Remove rrd folders for data is clean
sudo rm -Rf /opt/librenms/rrd/*
