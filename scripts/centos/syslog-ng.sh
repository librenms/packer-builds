#!/bin/bash -eux

if [[ "$SYSLOG_NG" == false ]]; then
    echo "Syslog-ng support disabled"
    exit 0
fi

sudo yum remove -y rsyslog
sudo yum install -y syslog-ng
sudo sh -c "echo '' > /var/log/secure"

sudo bash -c 'cat << EOF > /etc/syslog-ng/syslog-ng.conf
@version: 3.5
@include "scl.conf"

# First, set some global options.
options {
        chain_hostnames(off);
        flush_lines(0);
        use_dns(no);
        use_fqdn(no);
        owner("root");
        group("adm");
        perm(0640);
        stats_freq(0);
        bad_hostname("^gconfd$");
};

########################
# Sources
########################
source s_sys {
       system();
       internal();
};

source s_net {
        tcp(port(514) flags(syslog-protocol));
        udp(port(514) flags(syslog-protocol));
};

########################
# Destinations
########################
destination d_librenms {
        program("/opt/librenms/syslog.php" template ("\$HOST||\$FACILITY||\$PRIORITY||\$LEVEL||\$TAG||\$YEAR-\$MONTH-\$DAY \$HOUR:\$MIN:\$SEC||\$MSG||\$PROGRAM\n") template-escape(yes));
};

########################
# Log paths
########################
log {
        source(s_net);
        source(s_sys);
        destination(d_librenms);
};

###
# Include all config files in /etc/syslog-ng/conf.d/
###
@include "/etc/syslog-ng/conf.d/*.conf"
EOF'

sudo systemctl enable syslog-ng
sudo systemctl restart syslog-ng
sudo bash -c "echo '\$config[\"enable_syslog\"] = 1;' >> /opt/librenms/config.php"
