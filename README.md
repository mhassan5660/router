# Fiberhome GPON ONU Router - WAN Configuration Fix

## Problem
Internet (WAN) not working - WAN settings are commented out in network configuration.

## Solution

### Step 1: Connect to the Router
```bash
# Via SSH (if accessible)
ssh root@192.168.1.1

# Or access via web interface at http://192.168.1.1
```

### Step 2: Edit Network Configuration
```bash
# Backup original configuration
cp /etc/config/network /etc/config/network.bak

# Edit the network config file
vim /etc/config/network
# or
nano /etc/config/network
```

### Step 3: Uncomment WAN Settings
Look for commented WAN lines (starting with #) and uncomment them:

**Change from:**
```
# config interface 'wan'
# 	option ifname 'eth1'
# 	option proto 'dhcp'
```

**Change to:**
```
config interface 'wan'
	option ifname 'eth1'
	option proto 'dhcp'
```

### Step 4: Configure Firewall (if needed)
Edit `/etc/config/firewall` and ensure WAN zone is configured:

```bash
vim /etc/config/firewall
```

Uncomment or add WAN zone configuration.

### Step 5: Restart Network Services
```bash
# Option 1: Restart network service
/etc/init.d/network restart

# Option 2: Use UCI to commit and restart
uci commit
/etc/init.d/network reload
```

### Step 6: Verify Connection
```bash
# Check WAN interface status
ifconfig eth1
# or
ip addr show eth1

# Test connectivity
ping 8.8.8.8

# Check routing
route -n
# or
ip route show
```

## Configuration Details

### For DHCP (Dynamic IP from ISP)
```
config interface 'wan'
	option ifname 'eth1'
	option proto 'dhcp'
```

### For Static IP
```
config interface 'wan'
	option ifname 'eth1'
	option proto 'static'
	option ipaddr '203.x.x.x'
	option netmask '255.255.255.0'
	option gateway 'x.x.x.x'
	option dns '8.8.8.8 8.8.4.4'
```

### For VLAN Configuration (Some ISPs require this)
Check your ISP documentation for VLAN ID, then:

```
config interface 'wan'
	option ifname 'eth1.2'  # .2 is the VLAN ID (change as needed)
	option proto 'dhcp'
```

## Common Issues and Fixes

### Issue: Still no internet after enabling WAN
1. Check if eth1 is the correct WAN port (might be eth2 or eth3)
2. Verify cable is connected to WAN port
3. Check ISP requirements (VLAN, specific settings)

### Issue: WAN interface shows no IP address
```bash
# Restart DHCP client
udhcpc -i eth1
```

### Issue: Firewall blocking WAN traffic
Ensure firewall zone is properly configured:
```bash
# Check firewall config
cat /etc/config/firewall | grep -A 5 'wan'
```

## Files to Check/Modify
- `/etc/config/network` - Network interface configuration
- `/etc/config/firewall` - Firewall rules and zones
- `/etc/config/system` - System settings

## Debugging
```bash
# View all network interfaces
ifconfig -a

# Check routing table
route -n

# Test DNS resolution
nslookup google.com

# Monitor network status
cat /proc/net/route

# Check system logs
logread | tail -20
```

## Common WAN Port Names on Fiberhome
- eth0 - Usually LAN port
- eth1 - Usually WAN port
- For some models, check labels on the device

If unsure, SSH to router and run:
```bash
ip link show
```

This will list all network interfaces.
