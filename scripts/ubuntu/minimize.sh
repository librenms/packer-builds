#!/bin/bash -eu

if [[ "$DESKTOP" =~ ^(true|yes|on|1|TRUE|YES|ON])$ ]]; then
    exit
fi

echo "==> Disk usage before minimization"
df -h

echo "==> Installed packages before cleanup"
dpkg --get-selections | grep -v deinstall

# Remove some packages to get a minimal install
echo "==> Removing all linux kernels except the currrent one"
#dpkg --list | awk '{ print $2 }' | grep 'linux-image-3.*-generic' | grep -v $(uname -r) | xargs apt-get -y purge
apt-get -y purge `ls /boot/vmlinuz-* | sed -e '$d' | sed s/.*vmlinuz/linux-image/`
apt-get -y purge $(dpkg --list |egrep 'linux-image-[0-9]' |awk '{print $3,$2}' |sort -nr |tail -n +2 |grep -v $(uname -r) |awk '{ print $2}')
apt-get -y purge $(dpkg --list |grep '^rc' |awk '{print $2}')
echo "==> Removing linux source"
dpkg --list | awk '{ print $2 }' | grep linux-source | xargs apt-get -y purge
echo "==> Removing documentation"
dpkg --list | awk '{ print $2 }' | grep -- '-doc$' | xargs apt-get -y purge
#echo "==> Removing development packages"
#dpkg --list | awk '{ print $2 }' | grep -- '-dev$' | xargs apt-get -y purge
#echo "==> Removing development tools"
#dpkg --list | grep -i compiler | awk '{ print $2 }' | xargs apt-get -y purge
#apt-get -y purge cpp gcc g++
#apt-get -y purge build-essential git
#echo "==> Removing default system Ruby"
#apt-get -y purge ruby ri doc
#echo "==> Removing default system Python"
#apt-get -y purge python-dbus libnl1 python-smartpm python-twisted-core libiw30 python-twisted-bin libdbus-glib-1-2 python-pexpect python-pycurl python-serial python-gobject python-pam python-openssl libffi5
echo "==> Removing other oddities"
apt-get -y purge popularity-contest installation-report landscape-common wireless-tools wpasupplicant ubuntu-serverguide
apt-get -y purge nano

# Clean up the apt cache
apt-get -y autoremove --purge
apt-get -y clean

echo "==> Removing man pages"
rm -rf /usr/share/man/*
echo "==> Removing APT files"
find /var/lib/apt -type f | xargs rm -f
echo "==> Removing any docs"
rm -rf /usr/share/doc/*
echo "==> Removing caches"
find /var/cache -type f -exec rm -rf {} \;

# Zero out the free space to save space in the final image
dd if=/dev/zero of=/EMPTY bs=1M  || echo "dd exit code $? is suppressed"
rm -f /EMPTY
sync

echo "==> Disk usage after cleanup"
df -h
