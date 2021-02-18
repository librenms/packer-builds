#!/bin/bash

set -e
set -x
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv --resizefs
sudo sed -i -e 's,^\(ACTIVE_CONSOLES="/dev/tty\).*,\11",' /etc/default/console-setup
for f in /etc/init/tty[^1]*.conf; do
  sudo mv "$f"{,.bak}
done
