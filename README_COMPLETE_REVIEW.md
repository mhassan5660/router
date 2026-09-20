# Complete Fiberhome GPON ONU Router Review - Documentation Guide
**Complete Review Status:** ✅ Ready  
**Last Updated:** 2026-09-20  
**Router Model:** AN5506-04-FA | Firmware: RP2636

---

## Quick Navigation

### 👤 **I Just Want to Understand the Problem**
→ Read: **[ISSUE_SUMMARY.md](ISSUE_SUMMARY.md)**
- 5 min read
- Plain language explanation
- What's working, what's not, why
- What to do next

---

### 🔧 **I Want to Fix This**
→ Read: **[ACTION_PLAN.md](ACTION_PLAN.md)**
- Phase-by-phase fix instructions
- Multiple solution options
- Success criteria at each stage
- Timeline and blockers

---

### 🔍 **I Want to Diagnose the Exact Problem**
→ Run: **[diagnose-form-submission.sh](diagnose-form-submission.sh)**
```bash
bash diagnose-form-submission.sh
```
- Automated diagnostic tool
- Identifies form handler status
- Checks file permissions
- Reports findings clearly

---

### 📚 **I Want Technical Details**
→ Read: **[FORM_SUBMISSION_ANALYSIS.md](FORM_SUBMISSION_ANALYSIS.md)**
- Deep technical analysis
- 5 possible root causes with evidence
- Why each cause leads to this symptom
- Investigation steps for each cause

---

### 📋 **I Want Complete Firmware Analysis**
→ Read: **[COMPLETE_FIRMWARE_REVIEW.md](COMPLETE_FIRMWARE_REVIEW.md)**
- Full firmware code review
- All components analyzed
- Backend daemon analysis
- HTML/JavaScript evaluation

---

## Document Map

```
README (You are here)
│
├─ ISSUE_SUMMARY.md ────────────────────→ Start here if confused
│  - 3-layer architecture breakdown
│  - Timeline for fixes
│  - Success criteria
│
├─ ACTION_PLAN.md ──────────────────────→ Start here to fix
│  - Phase 1: Diagnose
│  - Phase 2: Fix (multiple options)
│  - Phase 3: Test
│  - Phase 4: Connect fiber
│
├─ diagnose-form-submission.sh ─────────→ Start here to investigate
│  - Automated tool (run on router)
│  - 7-step diagnostic process
│  - Actionable summary output
│
├─ FORM_SUBMISSION_ANALYSIS.md ────────→ Read for deep understanding
│  - Technical root cause analysis
│  - How form submission should work
│  - Why it's failing (5 theories)
│  - Investigation procedures
│
└─ COMPLETE_FIRMWARE_REVIEW.md ────────→ Read for complete context
   - Full code component analysis
   - Boot sequence documentation
   - Backend library breakdown
   - Previous findings
```

---

## The Problem at a Glance

| Aspect | Status | Details |
|--------|--------|---------|
| **Router Hardware** | ✅ OK | Device functioning normally |
| **Web Interface Buttons** | ✅ OK | HTML uncommented, visible |
| **Form Display** | ✅ OK | Fields display, accept input |
| **Form Submission** | ❌ BROKEN | Data not saved to config file |
| **Configuration File** | ❌ EMPTY | Shows `enable=0`, no credentials |
| **Backend Handler** | ❓ MISSING | CGI script not found or broken |
| **Permission System** | ⚠️ UNKNOWN | Web server may lack write access |
| **Fiber Connection** | ⏳ PENDING | Not connected yet (critical) |

**Root Cause:** Form handler (CGI script) not working properly  
**Evidence:** Form accepts input, config file stays unchanged  
**Impact:** Can't use web form to enter ISP credentials  

---

## How to Use These Documents

### If You're in a Hurry (5 min)
1. Read ISSUE_SUMMARY.md (overview)
2. Run diagnose-form-submission.sh (identify exact issue)
3. Jump to ACTION_PLAN.md for your specific issue

### If You Want to Understand Everything (30 min)
1. Read ISSUE_SUMMARY.md (overview)
2. Read FORM_SUBMISSION_ANALYSIS.md (technical details)
3. Read ACTION_PLAN.md (practical fixes)
4. Run diagnose-form-submission.sh (validate understanding)

### If You Want Deep Technical Knowledge (1 hour)
1. Read COMPLETE_FIRMWARE_REVIEW.md (full analysis)
2. Read FORM_SUBMISSION_ANALYSIS.md (form issue specifics)
3. Run diagnose-form-submission.sh (hands-on validation)
4. Review ACTION_PLAN.md for implementation

---

## Three-Layer Architecture

```
WEB INTERFACE LAYER (Frontend)
├─ Browser at http://192.168.1.1
├─ HTML pages in /fh/extend/web/internet/
├─ JavaScript form handling in /fh/extend/web/js/
└─ Status: ✅ WORKING (shows form correctly)
                    │
                    │ HTTP POST /goform/WanConnection
                    ▼
FORM HANDLER LAYER (Web Server Backend)
├─ webs daemon (/fh/extend/webs)
├─ CGI scripts in /fh/extend/web/cgi-bin/
├─ Should: Parse form → Write config → Return success
└─ Status: ❌ NOT WORKING (data not being saved)
                    │
                    │ Write to /fhcfg/WanCtlCfg.ini
                    ▼
CONFIGURATION LAYER (Backend Services)
├─ WanCtlCfg.ini (config file)
├─ l3mng daemon (loads config)
├─ udhcpcforwan (DHCP client)
├─ Network interfaces (eth1, etc)
└─ Status: ✅ READY (waiting for config to be saved)
```

**The Problem:** Layer 2 isn't functioning

---

## Recommended Reading Order

### For Users
1. **ISSUE_SUMMARY.md** - Understand what's happening
2. **ACTION_PLAN.md** - Know what to do
3. **diagnose-form-submission.sh** - Find exact cause
4. **FORM_SUBMISSION_ANALYSIS.md** - Understand the details

### For System Administrators
1. **COMPLETE_FIRMWARE_REVIEW.md** - Full system analysis
2. **FORM_SUBMISSION_ANALYSIS.md** - Problem focus
3. **ACTION_PLAN.md** - Implementation steps
4. **diagnose-form-submission.sh** - Automated diagnosis

### For Developers
1. **FORM_SUBMISSION_ANALYSIS.md** - Technical architecture
2. **COMPLETE_FIRMWARE_REVIEW.md** - Codebase details
3. **ACTION_PLAN.md** - Implementation options
4. **diagnose-form-submission.sh** - Debug tools

---

## Quick Facts

- **Device Type:** GPON ONU (Gigabit Passive Optical Network Unit)
- **Manufacturer:** Fiberhome
- **Model:** AN5506-04-FA
- **Firmware:** RP2636 (2018)
- **Current Issue:** WAN configuration form not persisting data
- **Root Cause:** Backend form handler not functioning
- **Severity:** High (prevents internet access)
- **Estimated Fix Time:** 15-60 minutes depending on root cause
- **Critical Blocker:** Fiber optic cable connection required for final step

---

## Key Files Referenced

| File | Purpose | Status |
|------|---------|--------|
| `/fhcfg/WanCtlCfg.ini` | WAN configuration | Currently: `enable=0`, all fields empty |
| `/fhcfg/DhcpServerParaCfg.ini` | DHCP server config | Modified to use 8.8.8.8 DNS ✅ |
| `/fh/extend/web/internet/wan_*.asp` | Web interface | Uncommented, buttons now show ✅ |
| `/fh/extend/web/cgi-bin/*` | Form handlers | Missing or not working ❌ |
| `/fh/extend/webs` | Web server daemon | Running but handlers broken |
| `/fh/extend/l3mng` | Config loader daemon | Working, waiting for config |

---

## Success Indicators

### Configuration Saved ✅
```bash
cat /fhcfg/WanCtlCfg.ini | head -15
# Should show:
enable=1                    (currently 0)
pppoeUserName=YOUR_USERNAME (currently empty)
pppoePwd=YOUR_PASSWORD      (currently empty)
natEnable=1                 (currently 0)
```

### Daemon Loaded Config ✅
```bash
ps aux | grep l3mng
ps aux | grep udhcpc
# Should show processes running
```

### WAN Interface Active ✅
```bash
ifconfig eth1
# Should show inet address (requires fiber connected)
```

### Internet Working ✅
```bash
ping 8.8.8.8
# Should show responses (requires fiber connected)
```

---

## Next Immediate Steps

1. **Today:** Read ISSUE_SUMMARY.md (5 minutes)
2. **Today:** Run diagnose-form-submission.sh on router (15 minutes)
3. **Today:** Share output, get specific fix recommendation
4. **Tomorrow:** Apply fix from ACTION_PLAN.md (30 minutes)
5. **Soon:** Connect fiber optic cable (critical next step)

---

## Support & Help

**For Understanding:** Read ISSUE_SUMMARY.md + FORM_SUBMISSION_ANALYSIS.md  
**For Fixes:** Read ACTION_PLAN.md + run diagnose-form-submission.sh  
**For Details:** Read COMPLETE_FIRMWARE_REVIEW.md  
**For Automation:** Run diagnose-form-submission.sh on your router  

Each document includes:
- Clear explanations
- Code examples
- Commands to run
- Expected output
- Troubleshooting tips

---

## Document Sizes

| Document | Size | Read Time |
|----------|------|-----------|
| ISSUE_SUMMARY.md | ~5 KB | 5-10 min |
| ACTION_PLAN.md | ~8 KB | 10-15 min |
| FORM_SUBMISSION_ANALYSIS.md | ~10 KB | 15-20 min |
| COMPLETE_FIRMWARE_REVIEW.md | ~15 KB | 20-30 min |
| diagnose-form-submission.sh | ~4 KB | 15 min to run |

**Total Time to Full Understanding:** 45-90 minutes including running tools

---

## Key Takeaways

1. **The Problem:** Web form accepts input but doesn't save it
2. **The Cause:** Form submission handler not working (missing, misconfigured, or no permissions)
3. **The Solution:** Run diagnostics to identify exact cause, then apply appropriate fix
4. **The Workaround:** Manually SSH in and edit config file directly
5. **The Best Option:** Wait for fiber connection and let ISP auto-provision

---

## License & Attribution

All analysis and documentation in this repository is provided as-is for informational purposes.

**Repository:** https://github.com/mhassan5660/router  
**Analysis Date:** September 2026  
**Analyst:** Claude AI
