#!/bin/bash -eux

sudo yum install -y cmake sqlite-devel openssl-devel libssh2-devel ruby gcc ruby-devel
sudo gem install oxidized
sudo gem install oxidized-script oxidized-web
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

