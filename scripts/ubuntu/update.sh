#!/bin/bash -eu

sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv --resizefs
# locale
echo "==> Configuring locales"
sed -i -e '/^[^# ]/s/^/# /' /etc/locale.gen
LANG=en_US.UTF-8
LC_ALL=$LANG
locale-gen --purge $LANG
update-locale LANG=$LANG LC_ALL=$LC_ALL

# Disable the release upgrader
echo "==> Disabling the release upgrader"
sed -i.bak 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades

echo "==> Disabling apt.daily.service"
systemctl stop apt-daily.timer
systemctl disable apt-daily.timer
systemctl daemon-reload

# install packages and upgrade
echo "==> Updating list of repositories"
apt -y update
if [[ $UPDATE  =~ true || $UPDATE =~ 1 || $UPDATE =~ yes ]]; then
    apt -y dist-upgrade
    apt -y autoremove --purge
fi
apt -y install build-essential linux-headers-generic
apt -y install ssh nfs-common vim curl perl git cloud-init
apt -y autoclean
apt -y clean

# Remove 5s grub timeout to speed up booting
sed -i -e 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' \
    -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="nosplash"/' \
    -e 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="console=tty1 console=ttyS0,115200"/' \
    -e 's/^#?GRUB_TERMINAL=.*/GRUB_TERMINAL="console serial"/' \
    /etc/default/grub
update-grub
exit 0
