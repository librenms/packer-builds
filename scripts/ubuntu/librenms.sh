#!/bin/bash -eux

if [[ -z "$LIBRENMS_VERSION" ]]; then
  LIBRENMS_VERSION="master"
fi

apt -y install software-properties-common
add-apt-repository universe
apt -y update
apt -y install acl curl composer fping git graphviz imagemagick mariadb-client mariadb-server mtr-tiny nginx-full nmap php7.4-cli php7.4-curl php7.4-fpm php7.4-gd php7.4-json php7.4-mbstring php7.4-mysql php7.4-snmp php7.4-xml php7.4-zip rrdtool snmp snmpd whois unzip python3-pymysql python3-dotenv python3-redis python3-setuptools

sudo useradd librenms -d /opt/librenms -M -s /bin/bash
echo "librenms:CDne3fwdfds" | sudo chpasswd
sudo usermod -a -G librenms www-data
sudo bash -c 'cat <<EOF > /etc/sudoers.d/librenms
Defaults:librenms !requiretty
librenms ALL=(ALL) NOPASSWD: ALL
EOF'
sudo chmod 440 /etc/sudoers.d/librenms

cd /opt
git clone https://github.com/librenms/librenms.git
chown -R librenms:librenms /opt/librenms
chmod 771 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
cd /opt/librenms
sudo -u librenms ./scripts/composer_wrapper.php install --no-dev

# Change php to UTC TZ
sudo sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.4/fpm/php.ini
sudo sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.4/cli/php.ini
mv /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/librenms.conf
sed -i "s/user = .*/user = librenms/" /etc/php/7.4/fpm/pool.d/librenms.conf
sed -i "s/group = .*/group = librenms/" /etc/php/7.4/fpm/pool.d/librenms.conf
sed -i "s|listen = .*|listen = /run/php-fpm-librenms.sock|" /etc/php/7.4/fpm/pool.d/librenms.conf
systemctl restart php7.4-fpm.service
systemctl enable php7.4-fpm.service

ln -s /opt/librenms/lnms /usr/bin/lnms
cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/

sudo cp /tmp/librenms.conf /etc/nginx/conf.d/librenms.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl enable nginx
sudo systemctl restart nginx

sudo cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

sudo apt install -y rrdcached
sudo mkdir /var/run/rrdcached
sudo chown librenms:librenms /var/run/rrdcached
sudo chmod 755 /var/run/rrdcached

bash -c 'cat << EOF > /etc/default/rrdcached
DAEMON=/usr/bin/rrdcached
DAEMON_USER=librenms
DAEMON_GROUP=librenms
WRITE_THREADS=4
WRITE_TIMEOUT=1800
WRITE_JITTER=1800
BASE_PATH=/opt/librenms/rrd/
JOURNAL_PATH=/var/lib/rrdcached/journal/
PIDFILE=/run/rrdcached.pid
SOCKFILE=/run/rrdcached.sock
SOCKGROUP=librenms
BASE_OPTIONS="-B -F -R"
EOF'
chown librenms:librenms /var/lib/rrdcached/journal/
systemctl restart rrdcached.service


sudo bash -c 'cat << EOF > /etc/mysql/mariadb.conf.d/99-librenms.cnf
[server]
innodb_file_per_table=1
lower_case_table_names=0
innodb_flush_log_at_trx_commit = 2
EOF'

sudo systemctl enable mysql
sudo systemctl restart mysql

mysql_pass="D42nf23rewD";

echo "CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;
            GRANT ALL PRIVILEGES ON librenms.*
            TO 'librenms'@'localhost'
            IDENTIFIED BY '$mysql_pass';
            FLUSH PRIVILEGES;" | mysql -u root

sudo cp /opt/librenms/config.php.default /opt/librenms/config.php
echo \$config[\'db_host\'] = \'localhost\'\; | tee -a /opt/librenms/config.php
echo \$config[\'db_user\'] = \'librenms\'\; | tee -a /opt/librenms/config.php
echo \$config[\'db_pass\'] = \'$mysql_pass\'\; | tee -a /opt/librenms/config.php
echo \$config[\'db_name\'] = \'librenms\'\; | tee -a /opt/librenms/config.php
echo \$config[\'rrdcached\'] = \'unix:/var/run/rrdcached.sock\'\; | tee -a /opt/librenms/config.php

echo "DB_HOST=localhost" | tee -a /opt/librenms/.env
echo "DB_DATABASE=librenms" | tee -a /opt/librenms/.env
echo "DB_USER=localhost" | tee -a /opt/librenms/.env
echo "DB_PASSWORD=$mysql_pass" | tee -a /opt/librenms/.env
echo "LIBRENMS_USER=librenms" | tee -a /opt/librenms/.env
echo "APP_URL=/" | tee -a /opt/librenms/.env
sed -i '/INSTALL=true/d' /opt/librenms/.env

# This does all the heavy lifting for the DB!
sudo -u librenms /usr/bin/lnms --force -n migrate

sudo -u librenms /usr/bin/lsnm -n config:set update_channel release

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

sudo -u librenms python3 -m pip install --user -r /opt/librenms/requirements.txt
cp /opt/librenms/misc/librenms.service /etc/systemd/system/librenms.service
systemctl enable librenms.service

sudo -u librenms /usr/bin/lnms -n user:add -p D32fwefwef -r admin -n librenms
sudo -u librenms /usr/bin/lnms -n --v2c device:add localhost

sudo git clone https://github.com/librenms-plugins/Weathermap.git /opt/librenms/html/plugins/Weathermap/
echo "INSERT INTO plugins SET plugin_name = 'Weathermap', plugin_active = 1;" | mysql -u root librenms
sudo bash -c "echo '*/5 * * * * librenms /opt/librenms/html/plugins/Weathermap/map-poller.php >> /dev/null 2>&1' >> /etc/cron.d/librenms"
chown -R librenms:librenms /opt/librenms/html/plugins/Weathermap/
chmod -R 775 /opt/librenms/html/plugins/Weathermap/configs/


sudo chown -R librenms:librenms /opt/librenms
sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
sudo chmod -R ug=rwX /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
