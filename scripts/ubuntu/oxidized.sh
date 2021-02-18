#!/bin/bash -eux

if [[ "$OXIDIZED" == false ]]; then
    echo "Oxidized support disabled"
    exit 0
fi
#TODO
exit 0
sudo add-apt-repository universe
sudo apt install -y ruby ruby-dev libsqlite3-dev libssl-dev pkg-config cmake libssh2-1-dev libicu-dev zlib1g-dev
sudo gem install oxidized
sudo gem install oxidized-script oxidized-web
sudo useradd oxidized -m
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

