#!/bin/bash -eux

if [ "$OXIDIZED" == false ]; then
    echo "Oxidized support disabled"
    exit 0
fi

sudo yum install -y make cmake which sqlite-devel openssl-devel libssh2-devel ruby gcc ruby-devel libicu-devel gcc-c++ rubygem-rake
sudo git clone https://github.com/ytti/oxidized.git /opt/oxidized/
sudo gem install bundler
sudo sh -c "(cd /opt/oxidized && rake install)"
sudo useradd oxidized
sudo bash -c 'cat << EOF > /etc/systemd/system/oxidized.service
[Unit]
Description=Oxidized - Network Device Configuration Backup Tool

[Service]
ExecStart=/usr/local/bin/oxidized
User=oxidized

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl enable oxidized

