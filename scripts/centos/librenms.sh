#!/bin/bash -eux

if [ -z "$LIBRENMS_VERSION"]; then
  LIBRENMS_VERSION="master"
fi

sudo yum install -y epel-release
sudo yum update -y
sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
sudo yum install -y composer cronie fping git ImageMagick jwhois mariadb mariadb-server mtr MySQL-python net-snmp net-snmp-utils nginx nmap php72w php72w-cli php72w-common php72w-curl php72w-fpm php72w-gd php72w-mbstring php72w-mysqlnd php72w-process php72w-snmp php72w-xml php72w-zip python-memcached rrdtool libargon2

sudo sh -c "cd /opt; composer create-project --no-dev --keep-vcs librenms/librenms:$LIBRENMS_VERSION librenms dev-master"


sudo useradd librenms -d /opt/librenms -M -r /bin/bash
echo "librenms:CDne3fwdfds" | sudo chpasswd
sudo usermod -a -G librenms nginx
sudo cp -r /etc/skel/. /opt/librenms

sudo bash -c 'cat <<EOF > /etc/sudoers.d/librenms
Defaults:librenms !requiretty
librenms ALL=(ALL) NOPASSWD: ALL
EOF'

sudo chmod 440 /etc/sudoers.d/librenms

# Change php to UTC TZ
sudo sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php.ini
sudo sed -i "s/^user =.*/user = nginx/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^group =.*/group = apache/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^listen =.*/listen = \/var\/run\/php-fpm\/php7.2-fpm.sock/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^;listen.owner =.*/listen.owner = nginx/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^;listen.group =.*/listen.group = nginx/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^;listen.mode =.*/listen.mode = 0660/" /etc/php-fpm.d/www.conf

sudo systemctl enable php-fpm
sudo systemctl restart php-fpm

sudo cp /tmp/librenms.conf /etc/nginx/conf.d/librenms.conf
sudo cp /tmp/nginx.conf /etc/nginx/nginx.conf

sudo rm -f /etc/httpd/conf.d/welcome.conf
sudo chgrp apache /var/lib/php/session/

sudo systemctl enable nginx
sudo systemctl restart nginx

sudo yum install -y policycoreutils-python
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/logs(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/logs(/.*)?'
sudo restorecon -RFvv /opt/librenms/logs/
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/rrd(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/rrd(/.*)?'
sudo restorecon -RFvv /opt/librenms/rrd/
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/storage(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/storage(/.*)?'
sudo restorecon -RFvv /opt/librenms/storage/
sudo semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/bootstrap/cache(/.*)?'
sudo semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/bootstrap/cache(/.*)?'
sudo restorecon -RFvv /opt/librenms/bootstrap/cache/
sudo setsebool -P httpd_can_sendmail=1
sudo setsebool -P httpd_execmem 1

sudo bash -c 'cat <<EOF > /tmp/http_fping.tt
module http_fping 1.0;

require {
type httpd_t;
class capability net_raw;
class rawip_socket { getopt create setopt write read };
}

#============= httpd_t ==============
allow httpd_t self:capability net_raw;
allow httpd_t self:rawip_socket { getopt create setopt write read };
EOF'

sudo checkmodule -M -m -o /tmp/http_fping.mod /tmp/http_fping.tt
sudo semodule_package -o /tmp/http_fping.pp -m /tmp/http_fping.mod
sudo semodule -i /tmp/http_fping.pp
sudo rm -f /tmp/http_fping.tt /tmp/http_fping.pp /tmp/http_fping.mod

sudo firewall-cmd --zone public --add-service http
sudo firewall-cmd --permanent --zone public --add-service http
sudo firewall-cmd --zone public --add-service https
sudo firewall-cmd --permanent --zone public --add-service https

sudo mkdir /var/run/rrdcached
sudo chown librenms:librenms /var/run/rrdcached
sudo chmod 755 /var/run/rrdcached

sudo bash -c 'cat << EOF > /etc/systemd/system/rrdcached.service
[Unit]
Description=Data caching daemon for rrdtool
After=network.service

[Service]
Type=forking
PIDFile=/run/rrdcached.pid
ExecStart=/usr/bin/rrdcached -w 1800 -z 1800 -f 3600 -s librenms -U librenms -G librenms -B -R -j /var/tmp -l unix:/var/run/rrdcached/rrdcached.sock -t 4 -F -b /opt/librenms/rrd/

[Install]
WantedBy=default.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable --now rrdcached.service

sudo bash -c 'cat << EOF > /etc/my.cnf.d/server.cnf
#
# These groups are read by MariaDB server.
# Use it for options that only the server (but not clients) should see
#
# See the examples of server my.cnf files in /usr/share/mysql/
#

# this is read by the standalone daemon and embedded servers
[server]
innodb_file_per_table=1
lower_case_table_names=0
EOF'

sudo systemctl restart mariadb
sudo systemctl enable mariadb

mysql_pass="D42nf23rewD";

echo "CREATE DATABASE librenms;
            GRANT ALL PRIVILEGES ON librenms.*
            TO 'librenms'@'localhost'
            IDENTIFIED BY '$mysql_pass';
            FLUSH PRIVILEGES;" | mysql -u root

sudo cp /opt/librenms/config.php.default /opt/librenms/config.php

sudo sed -i 's/USERNAME/librenms/g' /opt/librenms/config.php
sudo sed -i "s/PASSWORD/${mysql_pass}/g" /opt/librenms/config.php
sudo bash -c "echo '\$config[\"fping\"] = \"/usr/sbin/fping\";' >> /opt/librenms/config.php"
sudo bash -c "echo '\$config[\"rrdcached\"] = \"unix:/var/run/rrdcached/rrdcached.sock\";' >> /opt/librenms/config.php"
sudo bash -c "echo '\$config[\"update_channel\"] = \"release\";' >> /opt/librenms/config.php"

sudo bash -c 'cat <<EOF > /etc/snmp/snmpd.conf
rocommunity public 127.0.0.1
extend distro /usr/bin/distro
extend hardware "/bin/cat /sys/devices/virtual/dmi/id/product_name"
extend manufacturer "/bin/cat /sys/devices/virtual/dmi/id/sys_vendor"
EOF'
sudo curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
sudo chmod +x /usr/bin/distro
sudo systemctl restart snmpd
sudo systemctl enable snmpd

sudo cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
sudo sed -i "s/16/4/g" /etc/cron.d/librenms

sudo /usr/bin/php /opt/librenms/build-base.php
sudo /usr/bin/php /opt/librenms/addhost.php localhost public v2c
sudo /usr/bin/php /opt/librenms/adduser.php librenms D32fwefwef 10

sudo git clone https://github.com/librenms-plugins/Weathermap.git /opt/librenms/html/plugins/Weathermap/
echo "INSERT INTO plugins SET plugin_name = 'Weathermap', plugin_active = 1;" | mysql -u root librenms
sudo bash -c "echo '*/5 * * * * librenms /opt/librenms/html/plugins/Weathermap/map-poller.php >> /dev/null 2>&1' >> /etc/cron.d/librenms"
sudo chcon -R -t httpd_cache_t /opt/librenms/html/plugins/Weathermap/
sudo chmod -R g+w /opt/librenms/html/plugins/Weathermap/configs/


sudo chown -R librenms:librenms /opt/librenms
sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
sudo chmod -R ug=rwX /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
