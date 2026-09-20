# WAN Form Submission Issue - Root Cause Analysis
**Date:** 2026-09-20  
**Issue:** Web form accepts ISP credentials but doesn't save them to `/fhcfg/WanCtlCfg.ini`

---

## PROBLEM STATEMENT

When user enters WAN PPPoE credentials through the web form:
1. ✅ Form displays correctly (HTML uncommented, buttons visible)
2. ✅ User can type in the form fields (Username, Password)
3. ✅ Form submission appears to work (page doesn't error)
4. ❌ **Data is NOT saved to `/fhcfg/WanCtlCfg.ini`**
5. ❌ After checking the config file: `enable=0` and all fields remain empty

**Evidence:**
```bash
# After user entered credentials through web form:
cat /fhcfg/WanCtlCfg.ini | head -15

#[WAN0]
enable=0              ← STILL DISABLED (should be 1)
name=                 ← EMPTY (should have ISP name)
connectionMode=0
connectionType=0
natEnable=0           ← STILL DISABLED (should be 1)
dnsRealyEnable=1
lanPorts=0
ssidPorts=0
getIpMode=0
pppoeProxyEnable=0
pppoeUserName=        ← EMPTY (user entered value - NOT SAVED!)
pppoePwd=             ← EMPTY (user entered value - NOT SAVED!)
```

---

## ANALYSIS: How Web Form Submission Should Work

### 1. Frontend: Form Submission Flow

**File:** `/fh/extend/web/internet/wan_new.asp` (or wan_3bb.asp / wan_sfu.asp)

**Expected HTML structure:**
```html
<form method="post" action="/goform/WanConnection" id="form_wan">
  <!-- Form fields -->
  <input type="text" name="pppoeUserName" value="...">
  <input type="password" name="pppoePwd" value="...">
  <input type="hidden" name="wan_enable" value="1">
  <input type="hidden" name="nat_enable" value="1">
  
  <!-- Submit button -->
  <input type="submit" value="Submit">
</form>
```

**Expected JavaScript handler:**
```javascript
// Collect form data
var formData = {
  pppoeUserName: document.getElementById('username').value,
  pppoePwd: document.getElementById('password').value,
  wan_enable: 1,
  nat_enable: 1,
  // ... other fields
};

// POST to backend API
fetch('/goform/WanConnection', {
  method: 'POST',
  body: JSON.stringify(formData)  // OR traditional form encoding
});
```

---

### 2. Backend: Form Handler (CGI/API Script)

**Expected location:** `/fh/extend/webs/cgi-bin/WanConnection` or similar

**Expected functionality:**
```
1. Receive HTTP POST request with form data
2. Parse parameters: pppoeUserName, pppoePwd, wan_enable, etc.
3. Read current /fhcfg/WanCtlCfg.ini
4. Update [WAN0] section:
   - Set enable=1
   - Set pppoeUserName=<received value>
   - Set pppoePwd=<received value>
   - Set natEnable=1
   - ... other fields
5. Write updated config back to /fhcfg/WanCtlCfg.ini
6. Send response to client (HTTP 200 OK)
7. Frontend reloads or notifies user of success
8. l3mng daemon picks up config change and applies it
```

---

## WHY IT'S FAILING - Likely Root Causes

### Root Cause #1: Form Handler Not Implemented ⚠️ MOST LIKELY

**Symptom:** Form accepts input but nothing happens

**Why:** Fiberhome might not have implemented the form submission handler CGI script

**Evidence:**
- Firmware is from 2018 (RP2636) and may be unfinished
- Regional variants (wan_3bb.asp, wan_romania.asp) suggest code was tailored for different ISPs
- Some ISP profiles may not support manual WAN configuration

**What's likely missing:**
```
/fh/extend/webs/cgi-bin/WanConnection    ← MISSING
/fh/extend/webs/cgi-bin/WanAdd           ← MISSING
/fh/extend/webs/cgi-bin/WanDelete        ← PROBABLY EXISTS
```

**Evidence from the code:**
- Form action: `/goform/WanTr069Delete` (delete handler exists)
- But where is `/goform/WanAdd` or `/goform/WanConnection`?

---

### Root Cause #2: Form Posts to Wrong Endpoint ⚠️ POSSIBLE

**Symptom:** Form submits to endpoint that doesn't save config

**Why:** Form action attribute might point to a display handler instead of a config handler

**Likely scenario:**
```html
<!-- Instead of saving handler: -->
<form action="/goform/WanConnection" method="post">

<!-- It actually does: -->
<form action="/goform/WanDisplay" method="post">  ← Just displays, doesn't save
```

**Check:** Look at form action attribute in wan_new.asp, wan_3bb.asp

---

### Root Cause #3: Handler Exists But Has Wrong File Path ⚠️ POSSIBLE

**Symptom:** Handler runs but writes to wrong location

**Why:** Handler might be writing to `/etc/wan.conf` or `/tmp/wan_config` instead of `/fhcfg/WanCtlCfg.ini`

**Likely locations being written to instead:**
```
/tmp/WanCtlCfg.ini           ← Temporary file (lost on reboot)
/var/wan_config.ini          ← Wrong location
/etc/config/wan              ← UCI-style (not used here)
```

**Check:** Find where handler actually writes and verify it's `/fhcfg/WanCtlCfg.ini`

---

### Root Cause #4: Handler Lacks Write Permissions ⚠️ POSSIBLE

**Symptom:** Handler runs but fails silently when trying to write

**Why:** Web server daemon running as unprivileged user, can't write to `/fhcfg/`

**Typical issue:**
```bash
# /fh/extend/webs runs as user "www" or "webs"
# But /fhcfg/ is owned by root with restricted permissions

ls -l /fhcfg/
drwxr-x--- root root /fhcfg/     ← Only owner can write

# So www user can't modify files there
```

**Check:** Run this on router:
```bash
# Who does webs run as?
ps aux | grep webs
# www     1234  /fh/extend/webs ...

# Can www write to /fhcfg?
sudo -u www touch /fhcfg/test.txt   # Should fail if not allowed
```

---

### Root Cause #5: Form Encoding Mismatch ⚠️ LESS LIKELY

**Symptom:** Handler exists but doesn't receive form data

**Why:** Form data encoding doesn't match what handler expects

**Possible mismatches:**
```
Frontend sends:      Backend expects:
─────────────────    ──────────────────
application/json     application/x-www-form-urlencoded
URL-encoded          application/json
Multipart            URL-encoded
```

**Check:** Look at JavaScript form submission code and handler implementation

---

## INVESTIGATION STEPS - How to Diagnose

### Step 1: Identify the Form Action

**Check the actual ASP file:**
```bash
# Find what endpoint the Add button posts to
grep -A 10 "fw_add\|clickAdd\|form.*action" /fh/extend/web/internet/wan_new.asp
grep -A 10 "fw_add\|clickAdd\|form.*action" /fh/extend/web/internet/wan_3bb.asp
grep -A 10 "fw_add\|clickAdd\|form.*action" /fh/extend/web/internet/wan_sfu.asp
```

**Expected output:**
```html
<form action="/goform/WanConnection" method="post" id="form_wan">
```

**Record the action endpoint:** `/goform/WanConnection` or similar

---

### Step 2: Find the Form Handler

**Check if CGI script exists:**
```bash
# Fiberhome uses /goform/ prefix, so handler is likely:
find /fh/extend/web* -name "*wan*" -type f 2>/dev/null | grep -i cgi
find /fh/extend/web* -name "*connection*" -type f 2>/dev/null
find /fh/extend -name "WanConnection*" 2>/dev/null

# Or search in webs daemon:
strings /fh/extend/webs | grep -i "wanconnection\|WanAdd"
```

**Expected files:**
```
/fh/extend/webs/cgi-bin/WanConnection.cgi    ← Handler
/fh/extend/webs/cgi-bin/WanAdd.cgi           ← Add WAN
/fh/extend/webs/cgi-bin/WanDelete.cgi        ← Delete WAN
```

---

### Step 3: Check Web Server Logs

**Enable logging on router:**
```bash
# Start web server with debug logging
killall webs 2>/dev/null
/fh/extend/webs -L 3 -M 1 -S 100 -m all -d /tmp/webs_debug.log &

# Now submit the form through web UI...

# Check logs
tail -100 /tmp/webs_debug.log
tail -100 /var/log/webs.log
```

**Look for:**
- Form POST request received
- Parameter parsing errors
- File write attempts
- Permission denied errors

---

### Step 4: Monitor Config File Changes

**Watch for modifications:**
```bash
# Terminal 1: Monitor config file
watch -n 1 'md5sum /fhcfg/WanCtlCfg.ini'

# Terminal 2: Submit form through web UI
# (Use browser to navigate to WAN settings, fill form, click Submit)

# Check if md5sum changes (indicates file was modified)
# If no change → form handler didn't write to file
```

---

### Step 5: Test Manual Config Update

**Verify file can be written:**
```bash
# Check current permissions
ls -l /fhcfg/WanCtlCfg.ini

# Try to write a test value
echo "enable=1" | tee -a /fhcfg/WanCtlCfg.ini

# Check what user webs runs as
ps aux | grep webs | grep -v grep

# Test if that user can write
sudo -u <webs_user> bash -c 'echo test > /fhcfg/test.txt'
```

---

## SUSPECTED ROOT CAUSE

Based on Fiberhome firmware patterns, **Root Cause #1 is most likely: Form Handler Not Implemented**

**Why:**
1. Fiberhome is an ISP-focused company - ONUs normally have configs pushed by ISP via GPON OMCI
2. Manual WAN configuration is a rare use case
3. The firmware (RP2636 from 2018) is old and may not have complete implementation
4. The form handler for `/goform/WanConnection` or similar probably doesn't exist

**Evidence:**
- User can see the form (HTML uncommented)
- Form accepts input (JavaScript works)
- But nothing persists (backend handler missing)
- Similar pattern: `/goform/WanTr069Delete` likely exists for GPON auto-provisioning

---

## SOLUTION OPTIONS

### Option A: Enable Manual Configuration (If Handler Exists)
**If the handler exists but isn't working:**
1. Debug file permissions
2. Check handler code
3. Verify it's writing to correct location

### Option B: Implement Custom Handler
**If handler doesn't exist:**
1. Create a CGI script that accepts form data
2. Updates `/fhcfg/WanCtlCfg.ini`
3. Restarts l3mng daemon
4. Returns success response

**Handler pseudocode:**
```bash
#!/bin/sh
# /fh/extend/webs/cgi-bin/WanConnection

# Get form parameters
USERNAME=$(echo "$QUERY_STRING" | grep -oP 'pppoeUserName=\K[^&]+')
PASSWORD=$(echo "$QUERY_STRING" | grep -oP 'pppoePwd=\K[^&]+')

# Update config file
sed -i "s/pppoeUserName=/pppoeUserName=$USERNAME/" /fhcfg/WanCtlCfg.ini
sed -i "s/pppoePwd=/pppoePwd=$PASSWORD/" /fhcfg/WanCtlCfg.ini
sed -i 's/^enable=0/enable=1/' /fhcfg/WanCtlCfg.ini

# Restart daemon
killall l3mng
sleep 1
/fh/extend/l3mng &

echo "HTTP/1.1 200 OK"
echo "Content-Type: text/html"
echo ""
echo "<html><body>Configuration saved successfully</body></html>"
```

### Option C: Use Direct File Editing via SSH/Telnet
**Until form handler is fixed:**
```bash
# SSH into router and manually edit config
ssh admin@192.168.1.1
cd /fhcfg
nano WanCtlCfg.ini  # or use sed to update

# Manually apply changes
killall l3mng
/fh/extend/l3mng &
```

---

## NEXT STEPS - Recommended Investigation Order

1. **First:** Run Step 1 above - identify what endpoint the form action points to
2. **Second:** Run Step 2 - check if that endpoint/handler exists
3. **Third:** If handler exists, run Step 3 & 4 - debug why it's not working
4. **Fourth:** If handler missing, implement custom handler (Option B above)
5. **Fifth:** Test form submission again with handler in place

---

## FILE PERMISSIONS CHECK

Current file permissions might be blocking writes:

```bash
# Check if /fhcfg is writable by web server
ls -ld /fhcfg
# Likely output: drwxr-x--- root root /fhcfg    ← www user CAN'T write

# Check WanCtlCfg.ini itself
ls -l /fhcfg/WanCtlCfg.ini
# Likely output: -rw-r----- root root WanCtlCfg.ini  ← www user CAN'T write

# Fix: Make /fhcfg world-writable (or specifically for web server)
chmod 777 /fhcfg                    ← RISKY but works for testing
chmod 666 /fhcfg/WanCtlCfg.ini      ← Better: just make config writable
```

**Caution:** Making system files world-writable is a security risk. Better approach:
```bash
# Find which user web server runs as
ps aux | grep webs

# Change owner of config files to that user
chown www:www /fhcfg/WanCtlCfg.ini

# OR add group write permission
chmod g+w /fhcfg
chmod g+w /fhcfg/WanCtlCfg.ini
```

---

## SUMMARY

**Current state:**
- Form displays ✅
- Form accepts input ✅
- Form submits ✅
- Backend processes submission ❓ (unknown)
- Config file updates ❌ (NOT happening)

**Root cause:** Backend form handler is either missing, misconfigured, or lacks write permissions

**Next action:** Follow investigation steps above to determine exact cause, then implement appropriate fix
