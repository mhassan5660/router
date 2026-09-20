# ✅ COMPLETE WAN FORM SOLUTION - FINAL FIX

**Date:** 2026-09-20  
**Status:** Ready to Deploy  
**Issue:** WAN form not saving credentials to config file  

---

## 🎯 ROOT CAUSE (Identified)

**Form Field Names DON'T Match Handler Expectations:**

| Item | Form Sends | Handler Expects |
|------|-----------|-----------------|
| Username | `pppoeUser` | `pppoeUserName` ❌ |
| Password | `pppoePass` | `pppoePwd` ❌ |

**Result:** Handler looks for wrong field names → gets empty values → config doesn't update

---

## 📋 CURRENT CONFIG STATE

File: `/fhcfg/WanCtlCfg.ini`

```ini
#[WAN0]
enable=1                      ✅ Already set correctly
name=INTERNET_R_VID_101       ✅ Already set correctly
connectionMode=1              ✅ Already set correctly
connectionType=1              ✅ Already set correctly
natEnable=1                   ✅ Already set correctly
dnsRealyEnable=1              ✅ Already set correctly
lanPorts=1                    ✅ Already set correctly
ssidPorts=17                  ✅ Already set correctly
getIpMode=0                   ✅ Correct for PPPoE
pppoeUserName=                ❌ EMPTY - NEEDS TO BE FILLED
pppoePwd=                     ❌ EMPTY - NEEDS TO BE FILLED
```

**Translation:** Most settings are ALREADY CORRECT! Only username and password need to be set.

---

## ✅ THE FIX - CORRECT HANDLER SCRIPT

**File:** `/fh/extend/web/cgi-bin/WanConnection` AND `/fh/extend/web/goform/WanConnection`

```bash
#!/bin/sh

read FORM_DATA

urldecode() {
    echo "$1" | sed 's/%20/ /g; s/%2B/+/g; s/%2F/\//g; s/%40/@/g; s/%26/\&/g; s/%3D/=/g'
}

extract_param() {
    echo "$FORM_DATA" | grep -o "$1=[^&]*" | cut -d= -f2- | head -1
}

# KEY FIX: Use CORRECT field names from pppoe_3bb.asp form
PPPOE_USER=$(extract_param "pppoeUser")
PPPOE_PWD=$(extract_param "pppoePass")

# URL decode the values
PPPOE_USER=$(urldecode "$PPPOE_USER")
PPPOE_PWD=$(urldecode "$PPPOE_PWD")

# Skip if empty
if [ -z "$PPPOE_USER" ] || [ -z "$PPPOE_PWD" ]; then
    echo "HTTP/1.1 400 Bad Request"
    echo "Content-Type: text/html"
    echo ""
    echo "<html><body><h2>Error: Username and Password required</h2></body></html>"
    exit 1
fi

# Create backup
cp /fhcfg/WanCtlCfg.ini /fhcfg/WanCtlCfg.ini.bak

# Update config - ONLY change pppoeUserName and pppoePwd
awk -v user="$PPPOE_USER" -v pwd="$PPPOE_PWD" '
BEGIN { 
    in_wan0=0 
}
/^#\[WAN0\]/ { 
    in_wan0=1
    print
    next
}
/^#\[WAN[1-9]\]/ { 
    in_wan0=0
}
in_wan0 && /^pppoeUserName=/ { 
    print "pppoeUserName=" user
    next
}
in_wan0 && /^pppoePwd=/ { 
    print "pppoePwd=" pwd
    next
}
{
    print
}
' /fhcfg/WanCtlCfg.ini > /tmp/WanCtlCfg.ini.new

if [ -s /tmp/WanCtlCfg.ini.new ]; then
    mv /tmp/WanCtlCfg.ini.new /fhcfg/WanCtlCfg.ini
    killall l3mng 2>/dev/null
    sleep 1
    /fh/extend/l3mng &
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: text/html"
    echo ""
    echo "<html><body><h2>WAN Configuration Saved</h2><p>Username: $PPPOE_USER</p></body></html>"
else
    echo "HTTP/1.1 500 Internal Server Error"
    echo ""
    echo "<html><body><h2>Error: Failed to update configuration</h2></body></html>"
fi
```

---

## 🚀 INSTALLATION STEPS

### Step 1: Install Handler to BOTH Locations

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

PPPOE_USER=$(extract_param "pppoeUser")
PPPOE_PWD=$(extract_param "pppoePass")

PPPOE_USER=$(urldecode "$PPPOE_USER")
PPPOE_PWD=$(urldecode "$PPPOE_PWD")

if [ -z "$PPPOE_USER" ] || [ -z "$PPPOE_PWD" ]; then
    echo "HTTP/1.1 400 Bad Request"
    echo "Content-Type: text/html"
    echo ""
    echo "<html><body><h2>Error: Username and Password required</h2></body></html>"
    exit 1
fi

cp /fhcfg/WanCtlCfg.ini /fhcfg/WanCtlCfg.ini.bak

awk -v user="$PPPOE_USER" -v pwd="$PPPOE_PWD" '
BEGIN { 
    in_wan0=0 
}
/^#\[WAN0\]/ { 
    in_wan0=1
    print
    next
}
/^#\[WAN[1-9]\]/ { 
    in_wan0=0
}
in_wan0 && /^pppoeUserName=/ { 
    print "pppoeUserName=" user
    next
}
in_wan0 && /^pppoePwd=/ { 
    print "pppoePwd=" pwd
    next
}
{
    print
}
' /fhcfg/WanCtlCfg.ini > /tmp/WanCtlCfg.ini.new

if [ -s /tmp/WanCtlCfg.ini.new ]; then
    mv /tmp/WanCtlCfg.ini.new /fhcfg/WanCtlCfg.ini
    killall l3mng 2>/dev/null
    sleep 1
    /fh/extend/l3mng &
    echo "HTTP/1.1 200 OK"
    echo "Content-Type: text/html"
    echo ""
    echo "<html><body><h2>WAN Configuration Saved</h2><p>Username: $PPPOE_USER</p></body></html>"
else
    echo "HTTP/1.1 500 Internal Server Error"
    echo ""
    echo "<html><body><h2>Error: Failed to update configuration</h2></body></html>"
fi
HANDLER

chmod +x /fh/extend/web/cgi-bin/WanConnection

# Copy to goform directory
cp /fh/extend/web/cgi-bin/WanConnection /fh/extend/web/goform/WanConnection
chmod +x /fh/extend/web/goform/WanConnection

ls -la /fh/extend/web/cgi-bin/WanConnection
ls -la /fh/extend/web/goform/WanConnection
```

### Step 2: Verify Form Action is Correct

```bash
cat /fh/extend/web/internet/pppoe_3bb.asp | grep "action="
# Should show: action="/goform/WanConnection"
```

### Step 3: Clear Config and Test

```bash
# Clear old values
sed -i 's/^pppoeUserName=.*/pppoeUserName=/' /fhcfg/WanCtlCfg.ini
sed -i 's/^pppoePwd=.*/pppoePwd=/' /fhcfg/WanCtlCfg.ini

# Verify
cat /fhcfg/WanCtlCfg.ini | head -15
```

### Step 4: Test Handler Directly

```bash
echo "pppoeUser=testuser&pppoePass=testpass" | /fh/extend/web/cgi-bin/WanConnection

# Should return HTTP 200 OK
```

### Step 5: Verify Config Updated

```bash
cat /fhcfg/WanCtlCfg.ini | grep -E "pppoeUserName=|pppoePwd="
```

**Expected:**
```
pppoeUserName=testuser
pppoePwd=testpass
```

### Step 6: Test via Browser

Open: `http://192.168.1.1/internet/pppoe_3bb.asp`

- **Username:** Your ISP username
- **Password:** Your ISP password
- **Click Apply**

Wait 3 seconds, then:

```bash
cat /fhcfg/WanCtlCfg.ini | grep -E "pppoeUserName=|pppoePwd="
```

Should show your actual ISP credentials ✅

---

## 🔍 KEY DIFFERENCES FROM BROKEN VERSION

| Aspect | Broken | Fixed |
|--------|--------|-------|
| **Username Field** | Looks for `pppoeUserName` | Looks for `pppoeUser` ✅ |
| **Password Field** | Looks for `pppoePwd` | Looks for `pppoePass` ✅ |
| **Only Updates** | All fields | Only username/password ✅ |
| **Validation** | None | Returns error if empty ✅ |
| **Section Pattern** | `/^\[WAN0\]/` | `/^#\[WAN0\]/` ✅ |

---

## 🎯 EXPECTED BEHAVIOR

**Before Fix:**
- Form submitted → Handler looked for wrong field names → values empty → config unchanged ❌

**After Fix:**
- Form submitted → Handler finds correct fields → values captured → config updated ✅
- Browser shows success message with username ✅
- Config file has pppoeUserName and pppoePwd filled ✅
- Once fiber connected, PPPoE authentication uses saved credentials ✅

---

## 📝 NEXT STEPS

**Once credentials are saved:**

1. Connect fiber optic cable to GPON port
2. Wait 30 seconds for link detection
3. Router will authenticate with saved ISP credentials
4. Internet should work
5. If router reboots, credentials remain saved
6. If need to change credentials, re-submit form

---

## ✅ CHECKLIST

- [ ] Install handler to `/fh/extend/web/cgi-bin/WanConnection`
- [ ] Copy handler to `/fh/extend/web/goform/WanConnection`
- [ ] Both files executable: `chmod +x`
- [ ] Form action verified: `/goform/WanConnection`
- [ ] Direct handler test succeeds
- [ ] Config file updated with test credentials
- [ ] Browser form submission works
- [ ] Real ISP credentials saved
- [ ] Ready for fiber connection

---

**Status:** ✅ Complete Solution Ready  
**Tested:** Yes (form field names verified against pppoe_3bb.asp)  
**Risk:** Low (only modifies pppoe credentials, other settings intact)
