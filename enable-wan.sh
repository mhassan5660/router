#!/bin/bash
# Quick WAN Enable Script for Fiberhome GPON ONU Router
# Run this on your router: bash enable-wan.sh

set -e  # Exit on error

echo "======================================"
echo "Fiberhome GPON ONU - WAN Enable Script"
echo "======================================"

# Backup current configuration
echo "Creating backup..."
cp /etc/config/network /etc/config/network.backup.$(date +%Y%m%d_%H%M%S)

# Set WAN interface using UCI
echo "Configuring WAN interface..."

# Delete existing WAN config if present
uci delete network.wan 2>/dev/null || true

# Add WAN interface
uci set network.wan=interface
uci set network.wan.ifname='eth1'
uci set network.wan.proto='dhcp'

echo "Configuring WAN firewall zone..."

# Delete existing WAN zone if present
uci delete firewall.wan 2>/dev/null || true

# Add WAN firewall zone
uci set firewall.wan=zone
uci set firewall.wan.name='wan'
uci set firewall.wan.input='REJECT'
uci set firewall.wan.output='ACCEPT'
uci set firewall.wan.forward='REJECT'
uci set firewall.wan.masq='1'
uci set firewall.wan.network='wan'

# Add WAN->LAN forwarding rule
uci set firewall.wan_lan=forwarding
uci set firewall.wan_lan.src='wan'
uci set firewall.wan_lan.dest='lan'

# Commit changes
echo "Committing configuration..."
uci commit network
uci commit firewall

# Restart network
echo "Restarting network service..."
/etc/init.d/network restart
/etc/init.d/firewall restart

echo "======================================"
echo "WAN Configuration Complete!"
echo "======================================"
echo ""
echo "Verifying connection..."
sleep 3

# Check WAN status
echo ""
echo "WAN Interface Status:"
ifconfig eth1 || echo "eth1 not found, checking available interfaces..."
ip addr show eth1 2>/dev/null || true

# Check routing
echo ""
echo "Routing Table:"
route -n | head -10

# Test connectivity
echo ""
echo "Testing internet connectivity..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "✓ Internet connection successful!"
else
    echo "✗ Cannot reach 8.8.8.8. Checking configuration..."
    echo ""
    echo "Current network config:"
    uci show network.wan
fi

echo ""
echo "Log (last 10 lines):"
logread | tail -10
