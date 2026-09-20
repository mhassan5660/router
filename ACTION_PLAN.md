# WAN Configuration Issue - Action Plan
**Objective:** Get internet working on Fiberhome GPON ONU Router (AN5506-04-FA, Firmware RP2636)  
**Root Issue:** Web form accepts ISP credentials but doesn't save them to configuration file

---

## Current Situation

| Component | Status | Evidence |
|-----------|--------|----------|
| **Router Hardware** | ✅ OK | Physical device functioning |
| **Fiber Connection** | ⚠️ PENDING | Not connected yet (critical blocker) |
| **WAN Frontend** | ✅ OK | Buttons display after HTML uncomment |
| **WAN Form** | ✅ OK | Form displays, accepts input |
| **Form Submission** | ❌ BROKEN | Data not saved to config file |
| **Backend Config** | ❌ DISABLED | enable=0 in WanCtlCfg.ini |
| **ISP Provisioning** | ⏳ PENDING | Requires fiber connection + ISP activation |

---

## Root Cause Summary

**The Problem:** When you enter PPPoE username/password through the web form and click Submit, the data disappears. When you check `/fhcfg/WanCtlCfg.ini`, the fields are still empty and `enable=0`.

**Why It Happens:** The web form is working, but the **backend CGI handler that's supposed to receive the form data and save it to the configuration file is either:**
1. Missing entirely
2. Misconfigured
3. Lacking write permissions
4. Posting to the wrong endpoint

---

## Step-by-Step Action Plan

### PHASE 1: Diagnose the Problem (Today)

#### Step 1a: Run Diagnostic Script on Router

On your router, run:
```bash
cd /tmp
wget https://raw.githubusercontent.com/mhassan5660/router/claude/pensive-bell-jlnuqy/diagnose-form-submission.sh
bash diagnose-form-submission.sh
```

Or if wget isn't available:
```bash
# Copy diagnose-form-submission.sh to your router somehow and run it
bash diagnose-form-submission.sh
```

**What to look for in output:**
```
[STEP 1] Form action → Note the endpoint (e.g., /goform/WanConnection)
[STEP 2] Handler scripts → Are any WAN-related CGI files present?
[STEP 4] Permissions → Can web server write to /fhcfg?
[STEP 5] Binary search → Any handler references in webs binary?
```

#### Step 1b: Report Findings

Share with me:
1. The form action endpoint from [STEP 1]
2. Whether handler scripts exist from [STEP 2]
3. File permissions from [STEP 4]
4. Any errors from [STEP 6]

---

### PHASE 2: Fix the Issue (Based on Findings)

#### If Permissions Are the Problem (Most Likely)

**Symptom:** [STEP 4] shows web server user can't write to `/fhcfg/`

**Fix:**
```bash
# SSH into router
ssh admin@192.168.1.1

# Make config file writable
chmod 666 /fhcfg/WanCtlCfg.ini

# Or make entire /fhcfg/ writable (less secure but works)
chmod 777 /fhcfg/

# Restart web server
killall webs
/fh/extend/webs -L 3 -M 1 -S 100 -m all &

# Test form submission again through web interface
```

#### If Handler Doesn't Exist

**Symptom:** [STEP 2] shows no CGI handler scripts

**Workaround Option A: Manual Configuration via SSH**

Instead of using the web form, edit the config file directly:

```bash
# SSH into router
ssh admin@192.168.1.1

# Edit WAN configuration
cat > /tmp/wan_config.sh << 'EOF'
#!/bin/bash
# Update WanCtlCfg.ini with PPPoE credentials

# Enable WAN0
sed -i 's/^#\?\[WAN0\]/[WAN0]/' /fhcfg/WanCtlCfg.ini
sed -i '/#\?\[WAN0\]/,/^#\?\[WAN1\]/ s/^enable=.*/enable=1/' /fhcfg/WanCtlCfg.ini

# Set PPPoE username (replace YOUR_USERNAME)
sed -i '/#\?\[WAN0\]/,/^#\?\[WAN1\]/ s/^pppoeUserName=.*/pppoeUserName=YOUR_USERNAME/' /fhcfg/WanCtlCfg.ini

# Set PPPoE password (replace YOUR_PASSWORD)
sed -i '/#\?\[WAN0\]/,/^#\?\[WAN1\]/ s/^pppoePwd=.*/pppoePwd=YOUR_PASSWORD/' /fhcfg/WanCtlCfg.ini

# Enable NAT
sed -i '/#\?\[WAN0\]/,/^#\?\[WAN1\]/ s/^natEnable=.*/natEnable=1/' /fhcfg/WanCtlCfg.ini

echo "WAN configuration updated"
cat /fhcfg/WanCtlCfg.ini | head -20
EOF

bash /tmp/wan_config.sh

# Restart configuration daemon
killall l3mng
sleep 1
/fh/extend/l3mng &

# Verify changes took effect
sleep 2
cat /fhcfg/WanCtlCfg.ini | head -20
```

**Workaround Option B: Implement Custom Handler**

Create a simple CGI script that the form can submit to:

```bash
# SSH into router
ssh admin@192.168.1.1

# Create handler script
mkdir -p /fh/extend/web/cgi-bin

cat > /fh/extend/web/cgi-bin/WanConnection << 'EOF'
#!/bin/sh
# Simple WAN Configuration Handler

# Read form data from POST
read FORM_DATA

# Parse parameters (simple URL decode)
PPPOE_USER=$(echo "$FORM_DATA" | grep -o "pppoeUserName=[^&]*" | cut -d= -f2-)
PPPOE_PWD=$(echo "$FORM_DATA" | grep -o "pppoePwd=[^&]*" | cut -d= -f2-)

# URL decode (basic)
PPPOE_USER=$(echo -e "$(echo "$PPPOE_USER" | sed 's/+/ /g;s/%/\\x/g')")
PPPOE_PWD=$(echo -e "$(echo "$PPPOE_PWD" | sed 's/+/ /g;s/%/\\x/g')")

# Update config file
if [ -n "$PPPOE_USER" ]; then
    sed -i "s/^pppoeUserName=.*/pppoeUserName=$PPPOE_USER/" /fhcfg/WanCtlCfg.ini
fi

if [ -n "$PPPOE_PWD" ]; then
    sed -i "s/^pppoePwd=.*/pppoePwd=$PPPOE_PWD/" /fhcfg/WanCtlCfg.ini
fi

# Enable WAN
sed -i "s/^enable=0/enable=1/" /fhcfg/WanCtlCfg.ini

# Restart daemon
killall l3mng 2>/dev/null
sleep 1
/fh/extend/l3mng &

# Return success
echo "HTTP/1.1 200 OK"
echo "Content-Type: text/html"
echo "Content-Length: 50"
echo ""
echo "<html><body>Configuration saved</body></html>"
EOF

chmod +x /fh/extend/web/cgi-bin/WanConnection

# Restart web server
killall webs
/fh/extend/webs -L 3 -M 1 -S 100 -m all &

echo "Handler installed"
```

---

### PHASE 3: Test the Fix

#### Test 1: Verify Configuration File is Writable

```bash
# SSH to router
ssh admin@192.168.1.1

# Try to write a test value
echo "test_value" >> /tmp/test.txt
echo "test_value" >> /fhcfg/test.txt

# Check results
ls -la /tmp/test.txt /fhcfg/test.txt

# Clean up
rm /tmp/test.txt /fhcfg/test.txt
```

#### Test 2: Submit Form Through Web Interface

1. Open browser to `http://192.168.1.1`
2. Navigate to WAN Settings
3. Enter your ISP credentials:
   - Username: `your_isp_username`
   - Password: `your_isp_password`
4. Click "Submit" or "Add"
5. SSH to router and check:

```bash
ssh admin@192.168.1.1
cat /fhcfg/WanCtlCfg.ini | grep -E "pppoeUserName|pppoePwd|enable"
```

**Expected output:**
```
enable=1                           # ← Should be 1 (was 0)
pppoeUserName=your_isp_username    # ← Should show your username
pppoePwd=your_isp_password         # ← Should show your password
```

#### Test 3: Verify Daemon Loaded New Config

```bash
# Check if daemon restarted
ps aux | grep l3mng

# Check if WAN interface is up
ifconfig eth1    # or wan0, depending on setup

# Try DHCP on WAN (won't work without fiber, but should try)
/fh/extend/udhcpcforwan -i eth1 &
sleep 5
ps aux | grep udhcpc
ifconfig eth1
```

---

### PHASE 4: Connect to ISP (Critical Next Step)

**Until fiber optic cable is connected, nothing else will work.**

Once you have:
1. ✅ WAN configuration saved
2. ✅ ISP username/password entered
3. ⏳ **Fiber optic cable physically connected to GPON port**

Then:
1. Router will reach ISP's GPON network
2. ISP may auto-provision additional WAN settings
3. Router gets WAN IP address via DHCP
4. Internet becomes accessible

---

## Timeline & Expectations

| Phase | Action | Time | Blocker | Status |
|-------|--------|------|---------|--------|
| 1 | Run diagnostics | 15 min | None | Ready |
| 2a | Fix permissions | 5 min | Identified | Conditional |
| 2b | Implement handler | 30 min | Identified | Conditional |
| 3 | Test & verify | 10 min | Fixed issue | Conditional |
| 4 | Connect fiber | 10 min | Physical cable | **Critical** |

---

## Success Criteria

You'll know it's working when:

1. **Configuration persists:**
   ```bash
   cat /fhcfg/WanCtlCfg.ini | grep enable
   # Shows: enable=1 (not 0)
   ```

2. **Credentials are saved:**
   ```bash
   cat /fhcfg/WanCtlCfg.ini | grep pppoe
   # Shows: pppoeUserName=YOUR_USERNAME (not empty)
   # Shows: pppoePwd=YOUR_PASSWORD (not empty)
   ```

3. **WAN interface comes up** (after fiber connected):
   ```bash
   ifconfig eth1
   # Shows inet address: x.x.x.x (not just link-local)
   ```

4. **Internet is reachable:**
   ```bash
   ping 8.8.8.8
   # Shows replies from 8.8.8.8 (not "Network unreachable")
   ```

---

## If This Still Doesn't Work

Please share:
1. Output from `diagnose-form-submission.sh`
2. Relevant lines from `/fhcfg/WanCtlCfg.ini`
3. Output from `ps aux | grep -E "webs|l3mng"`
4. Any error messages from logs

---

## Alternative: Wait for ISP Auto-Provisioning

**Simplest solution:** Contact your ISP

1. Provide them the router's serial number (on label)
2. Ask them to provision the device in their management system
3. When provisioned, ISP will automatically send WAN settings via GPON OMCI
4. Configuration will populate without needing manual web form entry

This is the intended workflow for GPON ONUs - they're designed to be provisioned by ISP, not manually configured by users.

---

## Questions This Addresses

**Q: Why doesn't the form save?**  
A: Backend handler missing, misconfigured, or lacks permissions

**Q: Why does enable=0 stay at 0?**  
A: Form submission not reaching backend, or backend not processing it

**Q: Why can I see the form but not use it?**  
A: Frontend works (HTML uncommented), backend doesn't (form handler broken)

**Q: What if I connect fiber without fixing this?**  
A: ISP's GPON auto-provisioning may override your manual settings anyway

**Q: Is this a hardware issue?**  
A: No, this is a firmware/configuration issue, fixable in software
