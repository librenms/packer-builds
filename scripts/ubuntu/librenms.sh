#!/bin/bash -eux

if [ -z "$LIBRENMS_VERSION"]; then
  LIBRENMS_VERSION="master"
fi

sudo add-apt-repository universe
sudo apt update -y
sudo apt install -y curl composer fping git graphviz imagemagick mariadb-client mariadb-server mtr-tiny nginx-full nmap php7.2-cli php7.2-curl php7.2-fpm php7.2-gd php7.2-json php7.2-mbstring php7.2-mysql php7.2-snmp php7.2-xml php7.2-zip python-memcache python-mysqldb rrdtool snmp snmpd whois acl python-mysqldb

sudo useradd librenms -d /opt/librenms -M -r
sudo usermod -a -G librenms www-data

sudo bash -c 'cat <<EOF > /etc/sudoers.d/librenms
Defaults:librenms !requiretty
librenms ALL=(ALL) NOPASSWD: ALL
EOF'

sudo chmod 440 /etc/sudoers.d/librenms

sudo sh -c "cd /opt; composer create-project --no-dev --keep-vcs librenms/librenms:$LIBRENMS_VERSION librenms dev-master"

# Change php to UTC TZ
sudo sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.2/fpm/php.ini
sudo sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.2/cli/php.ini

sudo systemctl enable php7.2-fpm
sudo systemctl restart php7.2-fpm

sudo cp /tmp/librenms.conf /etc/nginx/conf.d/librenms.conf

sudo rm -f /etc/nginx/sites-enabled/default

sudo systemctl enable nginx
sudo systemctl restart nginx

sudo cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

sudo firewall-cmd --zone public --add-service http
sudo firewall-cmd --permanent --zone public --add-service http
sudo firewall-cmd --zone public --add-service https
sudo firewall-cmd --permanent --zone public --add-service https

sudo apt install -y rrdcached
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

sudo bash -c 'cat << EOF > /etc/mysql/mariadb.conf.d/50-server.cnf
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
sql-mode=""
EOF'

sudo systemctl enable mysql
sudo systemctl restart mysql

mysql_pass="D42nf23rewD";

echo "CREATE DATABASE librenms;
            GRANT ALL PRIVILEGES ON librenms.*
            TO 'librenms'@'localhost'
            IDENTIFIED BY '$mysql_pass';
            FLUSH PRIVILEGES;" | mysql -u root

sudo cp /opt/librenms/config.php.default /opt/librenms/config.php

sudo sed -i 's/USERNAME/librenms/g' /opt/librenms/config.php
sudo sed -i "s/PASSWORD/${mysql_pass}/g" /opt/librenms/config.php
sudo bash -c "echo '\$config[\"rrdcached\"] = \"unix:/var/run/rrdcached/rrdcached.sock\";' >> /opt/librenms/config.php"
sudo bash -c "echo '\$config[\"update_channel\"] = \"release\";' >> /opt/librenms/config.php"

sudo rm /etc/snmp/snmpd.conf
sudo bash -c "echo 'rocommunity public 127.0.0.1' > /etc/snmp/snmpd.conf"
sudo curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
sudo chmod +x /usr/bin/distro
sudo systemctl restart snmpd
sudo systemctl enable snmpd

sudo cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms

sudo /usr/bin/php /opt/librenms/build-base.php
sudo /usr/bin/php /opt/librenms/addhost.php localhost public v2c
sudo /usr/bin/php /opt/librenms/adduser.php librenms D32fwefwef 10

sudo git clone https://github.com/librenms-plugins/Weathermap.git /opt/librenms/html/plugins/Weathermap/
echo "INSERT INTO plugins SET plugin_name = 'Weathermap', plugin_active = 1;" | mysql -u root librenms

sudo cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms

sudo bash -c "echo '*/5 * * * * librenms /opt/librenms/html/plugins/Weathermap/map-poller.php >> /dev/null 2>&1' >> /etc/cron.d/librenms"

sudo sed -i "s/16/4/g" /etc/cron.d/librenms

sudo chown -R librenms:librenms /opt/librenms
#sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
#sudo setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
