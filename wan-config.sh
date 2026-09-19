#!/bin/bash
# Fiberhome GPON ONU Router - WAN Configuration Fix
# This script enables and configures the WAN interface

echo "Setting up WAN interface for Fiberhome GPON ONU Router..."

# Enable WAN interface
# uci set network.wan=interface
# uci set network.wan.ifname='eth1'  # or the appropriate WAN port
# uci set network.wan.proto='dhcp'   # or 'static' for fixed IP

# For VLAN configuration (if needed for your ISP)
# uci set network.wan.vlan=2          # Change based on your ISP requirement

# Configure WAN firewall zone
# uci set firewall.wan=zone
# uci set firewall.wan.name='wan'
# uci set firewall.wan.input='REJECT'
# uci set firewall.wan.output='ACCEPT'
# uci set firewall.wan.forward='REJECT'
# uci set firewall.wan.masq=1
# uci set firewall.wan.network='wan'

# Uncomment the above lines based on your configuration, then run:
# uci commit
# /etc/init.d/network restart
