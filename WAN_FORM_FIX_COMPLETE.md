# WAN Form Submission - Complete Issue & Fix Guide
**Analysis Date:** 2026-09-20  
**Issue:** Form accepts input but doesn't save to `/fhcfg/WanCtlCfg.ini`

---

## 🔴 ROOT CAUSE IDENTIFIED

### The Problem
1. **Frontend (JavaScript):** ✅ Working - Collects form data
2. **Form Submission:** ✅ Working - Sends POST to backend
3. **Backend Handler:** ❌ **NOT WORKING** - Doesn't save data properly

The **handler script we created has bugs** in how it parses and saves the data.

---

## 🔍 What's Breaking

### Issue #1: Sed Special Characters
The current handler uses:
```bash
sed -i "s/^pppoeUserName=.*/pppoeUserName=$PPPOE_USER/" /fhcfg/WanCtlCfg.ini
```

**Problem:** If `$PPPOE_USER` contains special characters (/, &, etc.), sed will break.

### Issue #2: Form Data Encoding
Web forms send data as URL-encoded:
```
pppoeUserName=user%40example.com&pppoePwd=pass%26word
```

The handler doesn't properly URL-decode this.

### Issue #3: Section-based Config Updates
The config file has sections like `#[WAN0]`, `#[WAN1]`. The sed commands don't target the specific section - they might update the wrong WAN interface.

### Issue #4: Line Termination
Sed might not handle all lines correctly without `$` anchors.

---

## ✅ COMPLETE FIX - Robust Handler

Replace the buggy handler with this robust version:

```bash
cat > /fh/extend/web/cgi-bin/WanConnection << 'HANDLER'
#!/bin/sh

# Robust WAN Configuration Handler
# Reads form data, validates, and safely updates config file

# Read POST data
read FORM_DATA

# URL decode function (basic)
urldecode() {
    echo "$1" | sed 's/%20/ /g; s/%2B/+/g; s/%2F/\//g; s/%40/@/g; s/%26/\&/g; s/%3D/=/g'
}

# Extract parameters (parse key=value pairs)
extract_param() {
    echo "$FORM_DATA" | grep -o "$1=[^&]*" | cut -d= -f2- | head -1
}

# Get form values
PPPOE_USER=$(extract_param "pppoeUserName")
PPPOE_PWD=$(extract_param "pppoePwd")
WAN_ENABLE=$(extract_param "wan_enable")
NAT_ENABLE=$(extract_param "nat_enable")

# URL decode
PPPOE_USER=$(urldecode "$PPPOE_USER")
PPPOE_PWD=$(urldecode "$PPPOE_PWD")

# Set defaults
[ -z "$WAN_ENABLE" ] && WAN_ENABLE="1"
[ -z "$NAT_ENABLE" ] && NAT_ENABLE="1"

# Backup config
cp /fhcfg/WanCtlCfg.ini /fhcfg/WanCtlCfg.ini.$(date +%s)

# Create temp config with updates
awk -v pppoe_user="$PPPOE_USER" \
    -v pppoe_pwd="$PPPOE_PWD" \
    -v wan_enable="$WAN_ENABLE" \
    -v nat_enable="$NAT_ENABLE" \
    '
    BEGIN { in_wan0=0 }
    
    # Detect WAN0 section
    /^\[WAN0\]/ || /^#\[WAN0\]/ { in_wan0=1; print; next }
    
    # Exit WAN0 section when hitting next section
    /^\[WAN[1-9]\]/ || /^#\[WAN[1-9]\]/ { in_wan0=0 }
    
    # Update fields in WAN0 section only
    in_wan0 && /^enable=/ {
        print "enable=" wan_enable
        next
    }
    
    in_wan0 && /^natEnable=/ {
        print "natEnable=" nat_enable
        next
    }
    
    in_wan0 && /^pppoeUserName=/ {
        print "pppoeUserName=" pppoe_user
        next
    }
    
    in_wan0 && /^pppoePwd=/ {
        print "pppoePwd=" pppoe_pwd
        next
    }
    
    # Print all other lines unchanged
    { print }
    
    ' /fhcfg/WanCtlCfg.ini > /tmp/WanCtlCfg.ini.new

# Verify temp file created
if [ -s /tmp/WanCtlCfg.ini.new ]; then
    mv /tmp/WanCtlCfg.ini.new /fhcfg/WanCtlCfg.ini
    
    # Restart daemon
    killall l3mng 2>/dev/null
    sleep 1
    /fh/extend/l3mng &
    
    # HTTP response - success
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: text/html"
    echo "Content-Length: 150"
    echo ""
    echo "<html><body>"
    echo "<h2>WAN Configuration Saved</h2>"
    echo "<p>Settings: User=$PPPOE_USER, Enable=$WAN_ENABLE, NAT=$NAT_ENABLE</p>"
    echo "<p>Restarting services...</p>"
    echo "</body></html>"
else
    # HTTP response - error
    echo "HTTP/1.1 500 Internal Server Error"
    echo "Content-Type: text/html"
    echo ""
    echo "<html><body><h2>Error</h2><p>Failed to update configuration</p></body></html>"
fi
HANDLER

chmod +x /fh/extend/web/cgi-bin/WanConnection
```

---

## 🚀 Installation Steps

### Step 1: Create Fixed Handler

Router console par ye paste karo:

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
awk -v pppoe_user="$PPPOE_USER" -v pppoe_pwd="$PPPOE_PWD" -v wan_enable="$WAN_ENABLE" -v nat_enable="$NAT_ENABLE" 'BEGIN{in_wan0=0} /^\[WAN0\]/{in_wan0=1;print;next} /^\[WAN[1-9]\]/{in_wan0=0} in_wan0 && /^enable=/{print "enable="wan_enable;next} in_wan0 && /^natEnable=/{print "natEnable="nat_enable;next} in_wan0 && /^pppoeUserName=/{print "pppoeUserName="pppoe_user;next} in_wan0 && /^pppoePwd=/{print "pppoePwd="pppoe_pwd;next} {print}' /fhcfg/WanCtlCfg.ini > /tmp/WanCtlCfg.ini.new
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

### Step 2: Restart Web Server

```bash
killall webs
sleep 2
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
sleep 3
ps aux | grep webs
```

### Step 3: Verify Handler

```bash
# Test directly
echo "pppoeUserName=testuser&pppoePwd=testpass&wan_enable=1&nat_enable=1" | /fh/extend/web/cgi-bin/WanConnection

# Check if config updated
cat /fhcfg/WanCtlCfg.ini | head -15
```

---

## 🧪 Testing the Form

### Browser Test

1. Open `http://192.168.1.1`
2. Go to WAN Settings
3. Enter:
   - **Username:** `isp_user123`
   - **Password:** `isp_pass123`
4. Click **Submit**
5. Check config:

```bash
cat /fhcfg/WanCtlCfg.ini | grep -E "^enable=|^pppoeUserName=|^pppoePwd=|^natEnable=" | head -4
```

**Expected Output:**
```
enable=1
natEnable=1
pppoeUserName=isp_user123
pppoePwd=isp_pass123
```

---

## 🔍 If Still Not Working

### Check 1: Form Action

```bash
grep -n "action=" /fh/extend/web/internet/wan_3bb.asp | head -2
grep -n "action=" /fh/extend/web/internet/wan_new.asp | head -2
```

Must show: `action="/goform/WanConnection"`

If not, edit the ASP file:

```bash
# Find the form in wan_3bb.asp and check its action attribute
```

### Check 2: Handler Logs

```bash
# Enable logging in handler (add to script):
echo "$(date): User=$PPPOE_USER" >> /tmp/wan.log

# Then check:
tail -20 /tmp/wan.log
```

### Check 3: Permissions

```bash
# Ensure handler is executable
ls -la /fh/extend/web/cgi-bin/WanConnection
chmod 755 /fh/extend/web/cgi-bin/WanConnection
```

---

## 📋 Summary

**What Fixed:**
1. ✅ Proper URL decoding of form data
2. ✅ Section-aware config updates (only updates WAN0, not other sections)
3. ✅ Safe sed replacement using awk instead
4. ✅ Proper error handling
5. ✅ Response codes for debugging

**Next Steps:**
1. Install robust handler script
2. Restart web server
3. Test via browser form
4. Verify config file updates

---

## 🎯 Expected Behavior After Fix

1. User enters credentials in web form
2. Clicks Submit
3. JavaScript POSTs to `/goform/WanConnection`
4. Handler receives data
5. Handler updates `/fhcfg/WanCtlCfg.ini`
6. l3mng daemon reloads config
7. User gets success page
8. Config persists across reboots

**Status:** Ready for implementation ✅
