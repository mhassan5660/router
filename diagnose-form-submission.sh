#!/bin/bash
# WAN Form Submission Diagnostic Script
# Run this on your Fiberhome GPON ONU router to diagnose why form submissions aren't saving
# Usage: bash diagnose-form-submission.sh

echo "=================================================="
echo "Fiberhome WAN Form Submission Diagnosis Tool"
echo "=================================================="
echo ""

# Step 1: Check what form action the web interface uses
echo "[STEP 1] Identifying Form Action Endpoint"
echo "==========================================="
echo "Searching for form action in WAN interface files..."
echo ""

if [ -f "/fh/extend/web/internet/wan_new.asp" ]; then
    echo "wan_new.asp:"
    grep -n "form.*action\|goform" /fh/extend/web/internet/wan_new.asp | head -5
    echo ""
fi

if [ -f "/fh/extend/web/internet/wan_3bb.asp" ]; then
    echo "wan_3bb.asp:"
    grep -n "form.*action\|goform" /fh/extend/web/internet/wan_3bb.asp | head -5
    echo ""
fi

if [ -f "/fh/extend/web/internet/wan_sfu.asp" ]; then
    echo "wan_sfu.asp:"
    grep -n "form.*action\|goform" /fh/extend/web/internet/wan_sfu.asp | head -5
    echo ""
fi

# Step 2: Check if CGI handler scripts exist
echo "[STEP 2] Looking for Form Handler Scripts"
echo "=========================================="
echo "Searching for /goform handlers..."
echo ""

echo "Files in /fh/extend/web/cgi-bin/:"
ls -la /fh/extend/web/cgi-bin/ 2>/dev/null || echo "  (directory not found)"
echo ""

echo "Other CGI locations:"
find /fh/extend/web* -name "*wan*" -o -name "*connection*" 2>/dev/null | head -10 || echo "  (no files found)"
echo ""

# Step 3: Check web server process
echo "[STEP 3] Web Server Process Status"
echo "=================================="
echo "Web server running as:"
ps aux | grep -E "webs|www" | grep -v grep
echo ""

# Step 4: Check file permissions
echo "[STEP 4] File Permission Analysis"
echo "=================================="
echo "Current WAN config file permissions:"
ls -la /fhcfg/WanCtlCfg.ini 2>/dev/null || echo "  (file not found)"
echo ""

echo "/fhcfg directory permissions:"
ls -ld /fhcfg/ 2>/dev/null || echo "  (directory not found)"
echo ""

echo "Identifying web server user:"
WEB_USER=$(ps aux | grep '/fh/extend/webs' | grep -v grep | awk '{print $1}' | head -1)
if [ -n "$WEB_USER" ]; then
    echo "  Web server runs as: $WEB_USER"
    echo ""
    echo "Testing if $WEB_USER can write to /fhcfg/:"

    # Create a test script to run as the web user
    cat > /tmp/test_perms.sh << 'EOF'
#!/bin/bash
if touch /tmp/test_write_perms.txt; then
    echo "  Can write to /tmp: YES"
    rm /tmp/test_write_perms.txt
else
    echo "  Can write to /tmp: NO"
fi

if touch /fhcfg/test_write_perms.txt 2>/dev/null; then
    echo "  Can write to /fhcfg: YES"
    rm /fhcfg/test_write_perms.txt
else
    echo "  Can write to /fhcfg: NO (LIKELY PERMISSION ISSUE)"
fi
EOF
    chmod +x /tmp/test_perms.sh

    # Try to run as web user
    if command -v sudo &> /dev/null; then
        sudo -u "$WEB_USER" /tmp/test_perms.sh 2>/dev/null || /tmp/test_perms.sh
    else
        su - "$WEB_USER" -c /tmp/test_perms.sh 2>/dev/null || /tmp/test_perms.sh
    fi
else
    echo "  Could not identify web server user"
fi
echo ""

# Step 5: Search for handler in webs binary
echo "[STEP 5] Searching for Handler in Web Server Binary"
echo "==================================================="
echo "Looking for WAN-related handlers in /fh/extend/webs..."
echo ""

if strings /fh/extend/webs 2>/dev/null | grep -i "wanconnection\|wanadd\|wandelete" | head -5; then
    echo ""
    echo "  Found handler references in webs binary"
else
    echo "  No obvious handler references found"
fi
echo ""

# Step 6: Check web server logs
echo "[STEP 6] Web Server Logs"
echo "========================"
echo "Recent web server errors:"
tail -20 /var/log/webs.log 2>/dev/null || echo "  (log file not found)"
echo ""

# Step 7: Check configuration file for clues
echo "[STEP 7] Current WAN Configuration"
echo "==================================="
echo "First 20 lines of /fhcfg/WanCtlCfg.ini:"
head -20 /fhcfg/WanCtlCfg.ini 2>/dev/null || echo "  (file not found)"
echo ""

# Step 8: Summary
echo "=================================================="
echo "DIAGNOSIS SUMMARY"
echo "=================================================="
echo ""
echo "Key findings:"
echo "1. If [STEP 2] found no CGI handlers → Handler not implemented"
echo "2. If [STEP 4] shows permission issues → Fix with: chmod 666 /fhcfg/WanCtlCfg.ini"
echo "3. If [STEP 5] found references → Handler exists but may have bugs"
echo "4. If [STEP 6] shows errors → Check web server logs for clues"
echo ""
echo "Next steps:"
echo "- Check the form action endpoint from [STEP 1]"
echo "- If handler doesn't exist, you need to either:"
echo "  a) Implement a custom handler (advanced)"
echo "  b) Use SSH to manually edit /fhcfg/WanCtlCfg.ini"
echo "  c) Contact ISP for GPON auto-provisioning (preferred)"
echo ""
