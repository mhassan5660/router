# EXACT ISSUE IDENTIFIED - WAN Form Submission Not Working

**Analysis Date:** 2026-09-20  
**Issue:** Web form accepts WAN credentials but doesn't save them to `/fhcfg/WanCtlCfg.ini`  
**Root Cause:** Backend form handler script has 4 critical bugs

---

## 🔴 THE EXACT PROBLEM

When user enters ISP credentials (username/password) in the web form at `http://192.168.1.1` and clicks Submit:

1. ✅ **Frontend works** - HTML form displays correctly (after uncommenting)
2. ✅ **Browser sends data** - POST request reaches `/goform/WanConnection`
3. ❌ **Backend handler fails** - Data not saved to `/fhcfg/WanCtlCfg.ini`
4. ❌ **Config stays empty** - `enable=0`, `pppoeUserName=""`, `pppoePwd=""`, `natEnable=0`

---

## 🔍 FOUR BUGS IDENTIFIED

### Bug #1: Unsafe Special Character Handling
**File:** `/fh/extend/web/cgi-bin/WanConnection`  
**Problem:**
```bash
sed -i "s/^pppoeUserName=.*/pppoeUserName=$PPPOE_USER/" /fhcfg/WanCtlCfg.ini
```
**Issue:** If `$PPPOE_USER` contains special characters (`/`, `&`, `@`, etc.), sed breaks:
- `/` = sed path delimiter (breaks regex)
- `&` = sed "insert matched text" operator (corrupts output)
- `@` = common in email addresses (breaks sed)

**Example:** User enters `isp@domain.com` → sed fails with error

---

### Bug #2: No URL Decoding
**File:** `/fh/extend/web/cgi-bin/WanConnection`  
**Problem:** Web forms send data URL-encoded:
```
Raw form input:  user@example.com
What gets sent:  pppoeUserName=user%40example.com&pppoePwd=pass%26word
Handler gets:    pppoeUserName=user%40example.com  (not decoded!)
```

**Issue:** Handler saves `user%40example.com` instead of `user@example.com`

---

### Bug #3: Section-Unaware Config Updates
**File:** `/fhcfg/WanCtlCfg.ini`  
**Problem:** Config has multiple sections:
```ini
[WAN0]
enable=0
pppoeUserName=
...

[WAN1]
enable=0
...

[WAN2]
enable=0
...
```

**Issue:** sed commands without section awareness can:
- Update wrong WAN interface
- Create duplicate lines
- Miss section headers

---

### Bug #4: Improper Line Anchoring
**Problem:** sed patterns without `$` anchor don't reliably match end of line:
```bash
sed -i "s/^enable=.*/enable=1/" file  # May match partial lines or duplicates
```

---

## ✅ SOLUTION PROVIDED

Complete rewrite of handler using **AWK instead of sed**:

**Location:** `/fh/extend/web/cgi-bin/WanConnection`

**Key Improvements:**
1. ✅ Proper URL decoding function
2. ✅ Section-aware parsing (only updates `[WAN0]`)
3. ✅ Safe variable passing (AWK `-v` flags, no shell expansion)
4. ✅ Backup creation before modification
5. ✅ Proper error handling
6. ✅ HTTP response codes for debugging

**Handler Script Features:**
- Reads form data via stdin
- Extracts parameters: `pppoeUserName`, `pppoePwd`, `wan_enable`, `nat_enable`
- URL-decodes each parameter
- Parses config file with AWK
- Updates only `[WAN0]` section
- Restarts `l3mng` daemon to reload config
- Returns HTTP 200 on success, 500 on error

---

## 📋 FILES REQUIRING CHANGES

| File | Change | Status |
|------|--------|--------|
| `/fh/extend/web/cgi-bin/WanConnection` | Replace with robust handler | ❌ Not Applied |
| `/fh/extend/web/cgi-bin/` | Ensure directory exists | ⚠️ May need creation |
| `/fhcfg/WanCtlCfg.ini` | Permissions may need chmod 666 | ⚠️ Check |

---

## 🚀 NEXT STEPS

### Step 1: Prepare Router
```bash
# SSH to router
ssh admin@192.168.1.1

# Create cgi-bin directory if needed
mkdir -p /fh/extend/web/cgi-bin

# Check permissions
ls -la /fhcfg/WanCtlCfg.ini
chmod 666 /fhcfg/WanCtlCfg.ini
```

### Step 2: Install Fixed Handler
Copy the complete handler script from `WAN_FORM_FIX_COMPLETE.md` section "🚀 Installation Steps" and install it at `/fh/extend/web/cgi-bin/WanConnection`

### Step 3: Restart Web Server
```bash
killall webs
sleep 1
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
```

### Step 4: Test
1. Open browser to `http://192.168.1.1`
2. Enter test credentials: `testuser` / `testpass`
3. Click Submit
4. SSH and verify:
```bash
cat /fhcfg/WanCtlCfg.ini | grep -E "^enable=|^pppoeUserName=|^pppoePwd="
```

**Expected output:**
```
enable=1
pppoeUserName=testuser
pppoePwd=testpass
```

---

## 📖 DETAILED DOCUMENTATION

Complete fix instructions with code, testing steps, and troubleshooting:
→ See: **WAN_FORM_FIX_COMPLETE.md**

Comprehensive analysis with architecture diagram:
→ See: **FORM_SUBMISSION_ANALYSIS.md**

Step-by-step action plan:
→ See: **ACTION_PLAN.md**

---

## ⚠️ CRITICAL NOTES

1. **Fiber Cable Not Connected** - This fix only handles manual web form submission. Internet won't work until fiber is physically connected.

2. **ISP Auto-Provisioning Preferred** - GPON ONUs are designed for ISP auto-provisioning via GPON OMCI. Manual configuration is a workaround.

3. **DHCP Issue Separate** - Router has a known DHCP client issue (clients receive 169.254.x.x instead of 192.168.1.x). This is a separate firmware issue.

---

**Status:** Issue identified ✅  
**Solution provided:** Complete ✅  
**Ready for implementation:** Yes ✅
