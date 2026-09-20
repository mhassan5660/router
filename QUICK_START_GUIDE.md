# WAN Form Fix - Quick Start Guide

**Status:** ✅ Issue identified and solved  
**Last Updated:** 2026-09-20

---

## 📖 Read These In Order:

### 1️⃣ **Understand the Problem (5 min)**
   → Read: **EXACT_ISSUE_FOUND.md**
   - What's broken and why
   - 4 specific bugs identified
   - Next steps for implementation

### 2️⃣ **See the Comparison (5 min)**
   → Read: **HANDLER_COMPARISON.md**
   - Broken handler code with bugs highlighted
   - Fixed handler code with improvements
   - Side-by-side comparison table
   - Real test case showing the difference

### 3️⃣ **Get Complete Fix (15 min)**
   → Read: **WAN_FORM_FIX_COMPLETE.md**
   - Full context of all 4 bugs
   - Complete robust handler script
   - Installation steps (copy-paste ready)
   - Testing procedures
   - Troubleshooting tips

### 4️⃣ **Understand Architecture (Optional, 20 min)**
   → Read: **FORM_SUBMISSION_ANALYSIS.md**
   - Deep technical dive
   - How form submission should work
   - Why each bug breaks it

---

## ⚡ Quick Fix (Copy-Paste)

### Step 1: SSH to Router
```bash
ssh admin@192.168.1.1
```

### Step 2: Create Handler Directory
```bash
mkdir -p /fh/extend/web/cgi-bin
chmod 777 /fh/extend/web/cgi-bin
chmod 666 /fhcfg/WanCtlCfg.ini
```

### Step 3: Install Fixed Handler
Copy this command to your router console:
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

### Step 4: Restart Web Server
```bash
killall webs 2>/dev/null
sleep 1
/fh/extend/webs -L 3 -M 1 -S 100 -m all &
sleep 2
```

### Step 5: Test via Browser
1. Open `http://192.168.1.1`
2. Go to WAN Settings
3. Enter test credentials:
   - Username: `testuser`
   - Password: `testpass`
4. Click Submit

### Step 6: Verify Config Was Saved
```bash
cat /fhcfg/WanCtlCfg.ini | grep -E "^enable=|^pppoeUserName=|^pppoePwd=|^natEnable="
```

**Expected output:**
```
enable=1
pppoeUserName=testuser
pppoePwd=testpass
natEnable=1
```

If you see these values, ✅ **the fix worked!**

---

## 🔍 THE 4 BUGS (Quick Reference)

| Bug | What | Why Bad | How Fixed |
|-----|------|---------|-----------|
| **#1** | No URL decoding | `user%40domain.com` saved instead of `user@domain.com` | Added `urldecode()` function |
| **#2** | Unsafe sed special chars | Password with `&` corrupts config | Using AWK with `-v` flags instead |
| **#3** | No section awareness | Could update wrong WAN interface | AWK state machine tracks `[WAN0]` section |
| **#4** | No error handling | Can't tell if it worked or failed | Backup created, HTTP 200/500 responses |

---

## ✅ Success Checklist

- [ ] Handler script installed at `/fh/extend/web/cgi-bin/WanConnection`
- [ ] Handler is executable: `ls -la /fh/extend/web/cgi-bin/WanConnection` shows `rwx`
- [ ] Web server restarted and listening on port 80
- [ ] Form submission returns HTTP 200 (success page displays)
- [ ] Config file updated: `grep pppoeUserName /fhcfg/WanCtlCfg.ini` shows your username
- [ ] Password saved correctly: `grep pppoePwd /fhcfg/WanCtlCfg.ini` shows your password
- [ ] Enable flag set to 1: `grep "^enable=" /fhcfg/WanCtlCfg.ini | head -1` shows `enable=1`

---

## ⚠️ Important Notes

1. **Fiber Not Connected?** 
   - This fix enables WAN configuration via web form
   - Internet won't work until fiber cable is connected to GPON port

2. **ISP Credentials?**
   - Replace `testuser`/`testpass` with actual ISP username/password
   - Test with credentials before connecting fiber

3. **DHCP Issue?**
   - Router has a separate DHCP client issue (devices getting 169.254.x.x)
   - This form fix is independent - doesn't affect DHCP
   - Separate from fiber/ISP issues

4. **Need Help?**
   - Check **EXACT_ISSUE_FOUND.md** for issue overview
   - Check **HANDLER_COMPARISON.md** for what changed
   - Check **WAN_FORM_FIX_COMPLETE.md** for complete details
   - Check **ACTION_PLAN.md** for step-by-step procedure

---

## 📋 Files in This Repository

| File | Purpose | Read Time |
|------|---------|-----------|
| **QUICK_START_GUIDE.md** | This file - quick reference | 3 min |
| **EXACT_ISSUE_FOUND.md** | Issue summary & 4 bugs | 5 min |
| **HANDLER_COMPARISON.md** | Broken vs fixed code | 5 min |
| **WAN_FORM_FIX_COMPLETE.md** | Complete solution with install steps | 10 min |
| **FORM_SUBMISSION_ANALYSIS.md** | Deep technical analysis | 20 min |
| **ACTION_PLAN.md** | 4-phase action plan | 10 min |
| **ISSUE_SUMMARY.md** | High-level overview | 10 min |
| **README_COMPLETE_REVIEW.md** | Navigation guide | 5 min |

---

## 🎯 Next Steps

1. **Read EXACT_ISSUE_FOUND.md** (5 min) - understand what's broken
2. **Read HANDLER_COMPARISON.md** (5 min) - see the fix
3. **Follow the Quick Fix steps above** (15 min) - install on router
4. **Test via browser** (5 min) - verify it works
5. **When ready:** Connect fiber cable for internet

---

**Total time to fix:** ~30 minutes  
**Difficulty:** Medium (requires SSH)  
**Risk:** Low (original config backed up)

Good luck! 🚀
