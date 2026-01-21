#!/bin/bash
set -euo pipefail

# Wait for internet in case setup.sh needs it
until curl -s --connect-timeout 5 http://www.google.com >/dev/null; do
    sleep 3
done

# Execute the setup.sh script fully independent w/ "nohup", "&", and "disown"
nohup /root/sc_node/setup.sh >> /var/log/setup.log 2>&1 </dev/null &; disown

# Self-cleanup: disable and remove the service
systemctl disable firstboot-setup.service
rm -f /etc/systemd/system/firstboot-setup.service
echo "First-boot chain completed at $(date)" >> /var/log/firstboot.log