#!/bin/bash -eu

# locale
echo "==> Configuring locales"
apt-get -y purge language-pack-en language-pack-gnome-en
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
systemctl mask apt-daily.service
systemctl daemon-reload

# install packages and upgrade
echo "==> Updating list of repositories"
apt-get -y update
if [[ $UPDATE  =~ true || $UPDATE =~ 1 || $UPDATE =~ yes ]]; then
    apt-get -y dist-upgrade
    apt-get -y autoremove --purge
fi
apt-get -y install build-essential linux-headers-generic
apt-get -y install ssh nfs-common vim curl perl git
apt-get -y autoclean
apt-get -y clean

# Disable IPv6
echo "==> Disabling IPv6"
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# Remove 5s grub timeout to speed up booting
sed -i -e 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' \
    -e 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet nosplash"/' \
    /etc/default/grub
update-grub
# SSH tweaks
echo "UseDNS no" >> /etc/ssh/sshd_config

# reboot
echo "====> Shutting down the SSHD service and rebooting..."
systemctl stop sshd.service
nohup shutdown -r now < /dev/null > /dev/null 2>&1 &
sleep 120
exit 0
