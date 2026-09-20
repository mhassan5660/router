# WAN Form Troubleshooting Guide

**Date:** 2026-09-20  
**Purpose:** Diagnose and fix web server and form submission issues  
**Current Status:** Web server not responding after restart attempts

---

## 🔴 IMMEDIATE DIAGNOSTICS (Run These First)

### Step 1: Check Web Server Process Status
```bash
ssh admin@192.168.1.1

# Check if webs process is running
ps aux | grep webs

# Expected output should show:
# /fh/extend/webs -L 3 -M 1 -S 100 -m all
```

**If webs is NOT running:**
- Go to **Fix #1: Start Web Server** below

**If webs IS running:**
- Go to **Step 2**

---

### Step 2: Check Port 80 Listening Status
```bash
# Check what's listening on port 80
netstat -tlnp | grep :80

# Or with newer systems:
ss -tlnp | grep :80

# Expected output should show:
# tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      xxxx/webs
```

**If port 80 is NOT listening:**
- Go to **Fix #1: Start Web Server** below

**If port 80 IS listening:**
- Go to **Step 3**

---

### Step 3: Test Web Server Response
```bash
# Test from router itself
curl http://127.0.0.1/ -v

# Or from a machine with network access to router:
curl http://192.168.1.1/ -v

# Expected: Should see HTTP response (200 or 404, but NOT "Connection refused")
```

**If Connection Refused or Timeout:**
- Web server is listening but not responding
- Go to **Fix #2: Restart Web Server Properly** below

**If HTTP response received:**
- Go to **Step 4**

---

### Step 4: Verify Handler Script Installation
```bash
# Check if handler exists and is executable
ls -la /fh/extend/web/cgi-bin/WanConnection

# Expected: -rwxr-xr-x (executable)
```

**If file doesn't exist or isn't executable:**
- Go to **Fix #3: Install Handler Script** below

**If file exists and is executable:**
- Go to **Step 5**

---

### Step 5: Test Handler Directly
```bash
# Send test form data to handler
echo "pppoeUserName=testuser&pppoePwd=testpass&wan_enable=1&nat_enable=1" | /fh/extend/web/cgi-bin/WanConnection

# Expected output should be:
# HTTP/1.1 200 OK
# Content-Type: text/html
# 
# <html><body><h2>WAN Configuration Saved</h2></body></html>
```

**If handler returns error:**
- Check handler script syntax
- Go to **Fix #3: Install Handler Script** below

**If handler succeeds:**
- Check config file was updated:
```bash
cat /fhcfg/WanCtlCfg.ini | grep -E "pppoeUserName=|pppoePwd=" | head -1
```

---

### Step 6: Test Form Submission via Web Browser
```bash
# From your computer, open:
http://192.168.1.1/internet/pppoe_3bb.asp

# Fill in:
# Username: testuser
# Password: testpass
# Click Submit

# Then on router, check if config was saved:
cat /fhcfg/WanCtlCfg.ini | grep -E "pppoeUserName=|pppoePwd=" | head -1

# Expected output:
# pppoeUserName=testuser
# pppoePwd=testpass
```

**If config NOT updated after form submission:**
- Go to **Issue #1: Form Data Not Reaching Handler** below

**If config IS updated:**
- ✅ **Form submission working!** Go to **Step 7**

---

### Step 7: Verify All Configuration Fields
```bash
# Check if all fields were updated correctly
cat /fhcfg/WanCtlCfg.ini | head -15

# Expected output:
# #[WAN0]
# enable=1
# name=INTERNET_R_VID_101
# connectionMode=1
# connectionType=1
# natEnable=1
# dnsRealyEnable=1
# lanPorts=1
# ssidPorts=17
# getIpMode=0
# pppoeProxyEnable=0
# pppoeUserName=testuser
# pppoePwd=testpass
```

**If any fields are NOT updated correctly:**
- Go to **Issue #2: Handler Not Updating All Fields** below

**If all fields are correct:**
- ✅ **Everything working!** Internet should work once fiber cable is connected

---

## ✅ FIXES

### Fix #1: Start Web Server

**Option A: Simple Restart (Recommended)**
```bash
ssh admin@192.168.1.1

# Kill any existing web server
killall -9 webs 2>/dev/null
sleep 1

# Start web server
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
sleep 2

# Verify it's running
ps aux | grep webs
netstat -tlnp | grep :80
```

**Option B: Check for Process Lock**
```bash
# If webs won't start, check for zombie processes
ps aux | grep webs | grep -v grep

# If you see multiple webs processes, kill all:
killall -9 webs
sleep 3

# Then start fresh
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
```

**Option C: Check System Resources**
```bash
# Check if system is out of memory/file descriptors
free -h
ulimit -a

# If memory is low (under 10MB free), may need reboot:
reboot
```

---

### Fix #2: Restart Web Server Properly

```bash
ssh admin@192.168.1.1

# Step 1: Kill all web processes
killall -9 webs 2>/dev/null
killall -9 webs_simple 2>/dev/null
sleep 2

# Step 2: Clean up any temporary files
rm -f /tmp/webs.pid
rm -f /tmp/webs*

# Step 3: Start fresh
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
sleep 3

# Step 4: Verify port is listening
netstat -tlnp | grep :80

# Step 5: Test with curl
curl http://127.0.0.1/ -v
```

---

### Fix #3: Install Handler Script

**Step 1: Create CGI-BIN Directory (if needed)**
```bash
ssh admin@192.168.1.1

mkdir -p /fh/extend/web/cgi-bin
chmod 755 /fh/extend/web
chmod 755 /fh/extend/web/cgi-bin
```

**Step 2: Install Handler**
```bash
cat > /fh/extend/web/cgi-bin/WanConnection << 'HANDLER'
#!/bin/sh
read FORM_DATA

urldecode() {
    echo "$1" | sed 's/%20/ /g; s/%2B/+/g; s/%2F/\//g; s/%40/@/g; s/%26/\&/g; s/%3D/=/g'
}

extract_param() {
    echo "$FORM_DATA" | grep -o "$1=[^&]*" | cut -d= -f2- | head -1
}

PPPOE_USER=$(extract_param "pppoeUserName")
PPPOE_PWD=$(extract_param "pppoePwd")
WAN_ENABLE=$(extract_param "wan_enable")
NAT_ENABLE=$(extract_param "nat_enable")

PPPOE_USER=$(urldecode "$PPPOE_USER")
PPPOE_PWD=$(urldecode "$PPPOE_PWD")

[ -z "$WAN_ENABLE" ] && WAN_ENABLE="1"
[ -z "$NAT_ENABLE" ] && NAT_ENABLE="1"

cp /fhcfg/WanCtlCfg.ini /fhcfg/WanCtlCfg.ini.bak

awk -v pppoe_user="$PPPOE_USER" -v pppoe_pwd="$PPPOE_PWD" -v wan_enable="$WAN_ENABLE" -v nat_enable="$NAT_ENABLE" '
BEGIN { in_wan0=0 }
/^#\[WAN0\]/ { in_wan0=1; print; next }
/^#\[WAN[1-9]\]/ { in_wan0=0 }
in_wan0 && /^enable=/ { print "enable=" wan_enable; next }
in_wan0 && /^natEnable=/ { print "natEnable=" nat_enable; next }
in_wan0 && /^name=/ { print "name=INTERNET_R_VID_101"; next }
in_wan0 && /^connectionMode=/ { print "connectionMode=1"; next }
in_wan0 && /^connectionType=/ { print "connectionType=1"; next }
in_wan0 && /^lanPorts=/ { print "lanPorts=1"; next }
in_wan0 && /^ssidPorts=/ { print "ssidPorts=17"; next }
in_wan0 && /^getIpMode=/ { print "getIpMode=0"; next }
in_wan0 && /^pppoeUserName=/ { print "pppoeUserName=" pppoe_user; next }
in_wan0 && /^pppoePwd=/ { print "pppoePwd=" pppoe_pwd; next }
{ print }
' /fhcfg/WanCtlCfg.ini > /tmp/WanCtlCfg.ini.new

if [ -s /tmp/WanCtlCfg.ini.new ]; then
    mv /tmp/WanCtlCfg.ini.new /fhcfg/WanCtlCfg.ini
    killall l3mng 2>/dev/null
    sleep 1
    /fh/extend/l3mng &
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: text/html"
    echo ""
    echo "<html><body><h2>WAN Configuration Saved</h2></body></html>"
else
    echo "HTTP/1.1 500 Internal Server Error"
    echo ""
    echo "<html><body><h2>Error</h2></body></html>"
fi
HANDLER

chmod +x /fh/extend/web/cgi-bin/WanConnection
```

**Step 3: Verify Installation**
```bash
ls -la /fh/extend/web/cgi-bin/WanConnection

# Should show: -rwxr-xr-x
```

**Step 4: Restart Web Server**
```bash
killall webs
sleep 1
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
```

---

## ❌ ISSUES & SOLUTIONS

### Issue #1: Form Data Not Reaching Handler

**Symptom:** Form submits successfully but config file not updated

**Diagnosis Steps:**
```bash
# Check if form action is correct
cat /fh/extend/web/internet/pppoe_3bb.asp | grep -A 1 "form action"

# Should show: action="/goform/WanConnection"
```

**If action is wrong:**
```bash
# Fix the form action
sed -i 's|action="/goform/PPPOECfg"|action="/goform/WanConnection"|g' /fh/extend/web/internet/pppoe_3bb.asp

# Restart web server
killall webs
sleep 1
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
```

**If action is correct but still not working:**
```bash
# Check web server error logs
tail -50 /var/log/web_server.log 2>/dev/null

# Check if CGI directory is being served
curl http://192.168.1.1/cgi-bin/ -v

# If 404, CGI directory not mapped properly
# May need to recreate at different path
```

---

### Issue #2: Handler Not Updating All Fields

**Symptom:** Some config fields updated but others still at default

**Diagnosis:**
```bash
# Check which fields are missing
cat /fhcfg/WanCtlCfg.ini | head -15

# If missing: name, connectionMode, connectionType, lanPorts, ssidPorts
# Then handler script doesn't have all update rules
```

**Solution:**
- Reinstall handler with **Fix #3** above - make sure to copy entire script

---

### Issue #3: Web Server Crashes After Restart

**Symptom:** Web server starts but then dies immediately or after a few requests

**Diagnosis:**
```bash
# Try to start with debug output
/fh/extend/webs -d -L 3 -M 1 -S 100 -m all

# Watch output for errors
# Common issues:
# - Address already in use (port 80 bound by another process)
# - Memory exhausted
# - Missing library files
```

**Solutions:**
```bash
# Kill any process using port 80
fuser -k 80/tcp 2>/dev/null
sleep 1

# Check available memory
free -h

# If low on memory, close other processes:
killall upnp 2>/dev/null
killall miniupnpd 2>/dev/null

# Try starting again
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
```

---

### Issue #4: Cannot Access 192.168.1.1

**Symptom:** "Connection refused" or "Connection timed out" when accessing router

**Diagnosis:**
```bash
# Check if you can reach router at all
ping 192.168.1.1

# If ping works but HTTP doesn't:
# 1. Check if webs is running
ps aux | grep webs

# 2. Check if port 80 is open
netstat -tlnp | grep :80

# 3. Try curl from router itself
curl http://127.0.0.1/ -v
```

**If webs not running:**
- See **Fix #1: Start Web Server** above

**If curl from router works but remote doesn't:**
- Likely firewall issue - check:
```bash
iptables -L -n | grep 80
ip6tables -L -n | grep 80
```

---

## 📋 QUICK CHECKLIST

Run these checks in order:

- [ ] Web server process running: `ps aux | grep webs`
- [ ] Port 80 listening: `netstat -tlnp | grep :80`
- [ ] Handler installed: `ls -la /fh/extend/web/cgi-bin/WanConnection`
- [ ] Handler executable: `test -x /fh/extend/web/cgi-bin/WanConnection && echo OK`
- [ ] Form action correct: `grep "action=" /fh/extend/web/internet/pppoe_3bb.asp`
- [ ] Web server responds: `curl http://127.0.0.1/ -v`
- [ ] Form submits: Test via browser at http://192.168.1.1/internet/pppoe_3bb.asp
- [ ] Config updated: `cat /fhcfg/WanCtlCfg.ini | grep pppoeUserName=`
- [ ] All fields correct: `cat /fhcfg/WanCtlCfg.ini | head -15`

---

## 🚀 NEXT STEPS AFTER FORM WORKS

Once form submission is confirmed working:

1. **Test with Real ISP Credentials**
   - Enter actual ISP PPPoE username and password
   - Submit form
   - Verify config updated with real credentials

2. **Connect Fiber Cable**
   - Once config is saved, connect fiber optic cable to GPON port
   - Wait 30 seconds for link detection
   - Check if router obtains IP via PPPoE

3. **Verify Internet Working**
   - Check WAN status: Check /fhcfg/WanCtlCfg.ini for ISP connection indicators
   - Devices should obtain IPs in 192.168.1.x range (not 169.254.x.x)
   - Test connectivity from devices

4. **If Issues After Fiber Connection**
   - May need to re-submit form (router may reboot due to fiber link)
   - Check `/fhcfg/WanCtlCfg.ini` still has credentials
   - Restart `l3mng` daemon: `killall l3mng && /fh/extend/l3mng &`

---

**Created:** 2026-09-20  
**For User:** mhassan5660  
**Status:** Ready for immediate use
