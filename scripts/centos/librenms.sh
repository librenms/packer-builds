#!/bin/bash -eux

sudo yum install -y epel-release
sudo yum update -y
sudo rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
sudo yum install composer cronie fping git ImageMagick jwhois mariadb mariadb-server mtr MySQL-python net-snmp net-snmp-utils nginx nmap php72w php72w-cli php72w-common php72w-curl php72w-fpm php72w-gd php72w-mbstring php72w-mysqlnd php72w-process php72w-snmp php72w-xml php72w-zip python-memcached rrdtool libargon2

sudo useradd librenms -d /opt/librenms -M -r
sudo usermod -a -G librenms nginx

sudo bash -c 'cat <<EOF > /etc/sudoers.d/librenms
Defaults:librenms !requiretty
librenms ALL=(ALL) NOPASSWD: ALL
EOF'
sudo chmod 440 /etc/sudoers.d/librenms

sudo sh -c 'cd /opt/librenms; composer create-project --no-dev --keep-vcs librenms/librenms librenms dev-master'

# Change php to UTC TZ
sudo sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php.ini
sudo sed -i "s/^user =.*/user = nginx/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^group =.*/group = apache/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^listen =.*/listen = /var/run/php-fpm/php7.2-fpm.sock/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^listen.owner =.*/listen.owner = nginx/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^listen.group =.*/listen.group = nginx/" /etc/php-fpm.d/www.conf
sudo sed -i "s/^listen.mode =.*/listen.mode = 0660/" /etc/php-fpm.d/www.conf

sudo systemctl enable php-fpm
sudo systemctl restart php-fpm

sudo bash -c 'cat << EOF > /etc/nginx/conf.d/librenms.conf
server {
 listen      80;
 server_name librenms.example.com;
 root        /opt/librenms/html;
 index       index.php;

 charset utf-8;
 gzip on;
 gzip_types text/css application/javascript text/javascript application/x-javascript image/svg+xml text/plain text/xsd text/xsl text/xml image/x-icon;
 location / {
  try_files $uri $uri/ /index.php?$query_string;
 }
 location /api/v0 {
  try_files $uri $uri/ /api_v0.php?$query_string;
 }
 location ~ \.php {
  include fastcgi.conf;
  fastcgi_split_path_info ^(.+\.php)(/.+)$;
  fastcgi_pass unix:/var/run/php-fpm/php7.2-fpm.sock;
 }
 location ~ /\.ht {
  deny all;
 }
}
EOF'

sudo bash -c 'cat << EOF > /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

}
EOF'

sudo rm -f /etc/httpd/conf.d/welcome.conf
sudo chgrp apache /var/lib/php/session/

sudo systemctl enable nginx
sudo systemctl restart nginx

sudo yum install policycoreutils-python
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

sudo bash -c 'cat << EOF > ~/http_fping.tt'
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

sudo checkmodule -M -m -o http_fping.mod ~/http_fping.tt
sudo semodule_package -o http_fping.pp -m http_fping.mod
sudo semodule -i http_fping.pp
sudo rm -f ~/http_fping.tt

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
innodb_file_per_table=1
lower_case_table_names=0
sql-mode=""
EOF'

mysql_pass="D42nf23rewD";

echo "CREATE DATABASE librenms;
            GRANT ALL PRIVILEGES ON librenms.*
            TO 'librenms'@'localhost'
            IDENTIFIED BY '$mysql_pass';
            FLUSH PRIVILEGES;" | mysql -u root

sudo systemctl restart mariadb
sudo systemcl enable mariadb

sudo cp /opt/librenms/config.php.default /opt/librenms/config.php

sudo sed -i 's/USERNAME/librenms/g' /opt/librenms/config.php
sudo sed -i "s/PASSWORD/${mysql_pass}/g" /opt/librenms/config.php
sudo bash -c "echo '\$config["fping"] = \"/usr/sbin/fping\";' >> /opt/librenms/config.php"
sudo bash -c "echo '\$config['rrdcached'] = \"unix:/var/run/rrdcached/rrdcached.sock\";' >> /opt/librenms/config.php"
sudo bash -c "echo '\$config['update_channel'] = \"release\";' >> /opt/librenms/config.php"

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
sudo setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
sudo setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
