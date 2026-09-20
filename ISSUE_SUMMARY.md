# Fiberhome GPON ONU Router - Complete Issue Summary
**Router Model:** AN5506-04-FA (RP2636 Firmware)  
**Issue Date:** September 2026  
**Status:** Root Cause Identified, Action Plan Ready

---

## Executive Summary

### The Problem
You have a Fiberhome GPON ONU router where:
1. ✅ The web interface shows WAN configuration form
2. ✅ You can enter ISP credentials (username, password)
3. ❌ **But the data doesn't persist** - nothing is saved
4. ❌ Every time you check, the config file is still empty

### The Root Cause
The **form submission handler in the backend is not working**. When you click "Submit," the web server receives your data but fails to save it to `/fhcfg/WanCtlCfg.ini` because:

**Most Likely:** The CGI script handler that should process form submissions doesn't exist or is misconfigured  
**Also Possible:** Permission issue - web server can't write to config file  
**Less Likely:** Form is posting to wrong endpoint

### The Impact
- Internet doesn't work (WAN interface not configured)
- Manual web form can't be used to enter ISP credentials
- Workaround: SSH into router and manually edit config file

### The Solution
Three options, in order of preference:

| Option | Effort | Prerequisites | Result |
|--------|--------|----------------|--------|
| **Run diagnostics** | 15 min | SSH access | Identify exact cause |
| **Fix permissions** | 5 min | SSH access | Form may start working |
| **Manual SSH config** | 10 min | SSH access | ISP credentials saved |
| **ISP auto-provision** | Best | Fiber connection | ISP configures everything |

---

## What You've Already Done

✅ **Analysis Complete**
- Identified that WAN is disabled in `/fhcfg/WanCtlCfg.ini`
- Uncommented HTML form code so buttons now display
- Modified DNS settings from self-referential to Google DNS
- Enabled WAN0 backend with `enable=1`
- Attempted to enter ISP credentials through form
- Discovered credentials aren't being saved

❌ **Form Submission Not Working**
- Form accepts input (fields populate correctly)
- But data doesn't persist to config file
- Indicates backend handler issue

⏳ **Waiting On**
- Fiber optic cable connection (critical for any WAN functionality)
- ISP activation/provisioning (required for auto-configuration)

---

## How to Proceed

### IMMEDIATELY (Next 30 minutes)

**Step 1: Run Diagnostic Script**
```bash
# SSH to router
ssh admin@192.168.1.1

# Download and run diagnostic tool
bash diagnose-form-submission.sh 2>&1 | tee diagnostic_output.txt

# Share the output
```

This will tell us:
- What endpoint the form is trying to reach
- Whether the handler script exists
- If there are permission issues
- Any relevant error messages

### SHORT TERM (Next 1-2 days)

**Option A: If Permissions Are the Issue**
```bash
# Fix write permissions
chmod 666 /fhcfg/WanCtlCfg.ini

# Restart web server
killall webs
/fh/extend/webs -L 3 -M 1 -S 100 -m all &

# Try form submission again
```

**Option B: If Handler Is Missing**
```bash
# Use provided custom handler script
bash implement-form-handler.sh

# Or manually edit config file
# See ACTION_PLAN.md for detailed steps
```

### LONG TERM (1-2 weeks)

**Critical: Connect Fiber Optic Cable**

Once you have fiber connected:
1. Physical cable to GPON port
2. Router connects to ISP's GPON network
3. ISP auto-provisions WAN settings
4. Internet starts working

This is the **intended workflow** for GPON ONUs - ISP provisions them, not users.

---

## Understanding the Architecture

### The Three Layers

```
┌─────────────────────────────────────────────────────────┐
│  LAYER 1: Web Interface (Browser)                       │
│  - ASP pages in /fh/extend/web/internet/               │
│  - HTML forms, JavaScript buttons                       │
│  - Status: ✅ WORKING (buttons display after uncomment) │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP POST /goform/WanConnection
                     ▼
┌─────────────────────────────────────────────────────────┐
│  LAYER 2: Web Server & Form Handler                     │
│  - webs daemon (/fh/extend/webs)                        │
│  - CGI scripts (/fh/extend/web/cgi-bin/)               │
│  - Status: ⚠️ PROBLEM HERE (handler missing/broken)     │
└────────────────────┬────────────────────────────────────┘
                     │ Write config to /fhcfg/WanCtlCfg.ini
                     ▼
┌─────────────────────────────────────────────────────────┐
│  LAYER 3: Configuration & Backend Services              │
│  - WanCtlCfg.ini (configuration file)                   │
│  - l3mng daemon (loads config)                          │
│  - udhcpcforwan (DHCP client)                           │
│  - Network interfaces (eth1, wan0, etc)                 │
│  - Status: ✅ READY (waiting for config to be saved)    │
└─────────────────────────────────────────────────────────┘
```

**The Problem:** Layer 2 isn't functioning properly - form submissions aren't reaching or saved to Layer 3

---

## Reference Documents

### In This Repository

1. **FORM_SUBMISSION_ANALYSIS.md**
   - Detailed technical explanation of the issue
   - 5 possible root causes with evidence
   - Investigation steps to diagnose exact cause

2. **ACTION_PLAN.md**
   - Step-by-step fix procedures
   - Multiple solution options
   - Clear success criteria

3. **diagnose-form-submission.sh**
   - Automated diagnostic tool
   - Run this first to identify root cause
   - Provides actionable summary

4. **COMPLETE_FIRMWARE_REVIEW.md**
   - Full firmware code analysis
   - Architecture and boot sequence
   - Backend component documentation

### Previous Reviews

- **FIRMWARE_CODE_REVIEW.md** - Earlier analysis identifying WAN disabled

---

## Technical Deep Dive (Optional Reading)

### Why This Happens in Fiberhome Firmware

Fiberhome GPON ONUs are designed for ISP provisioning, not consumer self-service:

1. **ISP-Centric Design**
   - Firmware expects ISP to provision everything via GPON OMCI
   - Manual WAN configuration is a rare use case
   - May not be fully tested in firmware

2. **Regional Variants**
   - Firmware has regional variants (wan_3bb.asp, wan_romania.asp, wan_jiangsu.asp)
   - Different ISPs = different configurations
   - Your model may not have full WAN support enabled

3. **Old Firmware**
   - RP2636 is from 2018
   - May be incomplete or have known bugs
   - Firmware updates might fix this, but likely unavailable for this model

4. **Security Model**
   - Some ISPs intentionally disable manual WAN config
   - Prevents subscribers from misconfiguring the device
   - Or allows ISP to lock down settings

---

## Success Criteria

### Level 1: Configuration Persists (Near-term)
```bash
cat /fhcfg/WanCtlCfg.ini | grep -E "^enable=|^pppoeUserName=|^pppoePwd="
# Should show:
# enable=1
# pppoeUserName=YOUR_ISP_USERNAME
# pppoePwd=YOUR_ISP_PASSWORD
```

### Level 2: Daemon Recognizes Config
```bash
ps aux | grep l3mng
/fh/extend/l3mng running with PID nnnn

ps aux | grep udhcpc
udhcpcforwan process should exist (after daemon restart)
```

### Level 3: WAN Interface Gets IP (With Fiber)
```bash
ifconfig eth1
# Should show inet addr: x.x.x.x (not just link-local 169.254.x.x)
```

### Level 4: Internet Accessible
```bash
ping 8.8.8.8
# Should show responses, not "Network is unreachable"
```

---

## FAQ

**Q: Do I need to connect fiber before anything works?**  
A: You can test form submission and configuration persistence. But to actually get an IP address, yes, fiber must be connected.

**Q: Why did the HTML uncomment fix buttons but not functionality?**  
A: Frontend (HTML/JavaScript) is separate from backend (form handler/config saving). Uncommenting fixed display, but the form handler still wasn't working.

**Q: What if ISP doesn't support manual configuration?**  
A: Most ISPs use auto-provisioning via GPON OMCI. Manual configuration is rare. Better to work with ISP's provisioning system.

**Q: Is my router broken?**  
A: No, it's a firmware design issue, not a hardware defect. Likely intentional (ISP-controlled devices don't need user configuration).

**Q: Can I upgrade firmware?**  
A: Fiberhome doesn't provide public firmware updates. ISP might have updates, contact them.

**Q: What if the diagnostic script shows handler exists?**  
A: Then handler has a bug (wrong file path, permission issue, etc). FORM_SUBMISSION_ANALYSIS.md covers debugging steps.

---

## Next Steps

1. **Read:** ACTION_PLAN.md (practical steps)
2. **Run:** `bash diagnose-form-submission.sh` on your router
3. **Share:** Diagnostic output with me
4. **Act:** Follow fixes based on diagnostic results
5. **Test:** Verify configuration persists
6. **Connect:** Physical fiber cable when ready
7. **Verify:** Internet connectivity once provisioned

---

## Contact & Support

If you need help:
1. Share diagnostic output from the script
2. Provide relevant log excerpts
3. Describe what you've tried
4. Include commands you ran and their output

All investigation documents are in this repository.
