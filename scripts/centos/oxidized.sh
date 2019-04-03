#!/bin/bash -eux

if [ "$OXIDIZED" == false ]; then
    echo "Oxidized support disabled"
    exit 0
fi

sudo yum install -y centos-release-scl
sudo yum install -y make cmake which sqlite-devel openssl-devel libssh2-devel ruby gcc ruby-devel libicu-devel gcc-c++ rubygem-rake
sudo yum install -y rh-ruby23 rh-ruby23-ruby-devel
sudo useradd oxidized
sudo su - librenms -c "source scl_source enable rh-ruby23 && gem install oxidized"
sudo su - librenms -c "source scl_source enable rh-ruby23 && gem install oxidized-script oxidized-web"
sudo bash -c 'cat << EOF > /etc/profile.d/rh-ruby23.sh
#!/bin/bash

source scl_source enable rh-ruby23
EOF'
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

