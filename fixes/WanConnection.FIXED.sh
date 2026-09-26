#!/bin/sh
# Fixed WAN Connection Configuration Script
# Addresses: Command injection, input validation, temp file security, logging

set -e

LOG_FILE="/var/log/wan_config.log"
RATE_LIMIT_WINDOW=300
RATE_LIMIT_COUNT=5

# Secure logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${REMOTE_ADDR:-unknown}] $*" >> "$LOG_FILE" 2>/dev/null
}

# Secure URL decoding (avoid sed injection)
urldecode() {
    local url_encoded="$1"
    local decoded=""
    local i="${#url_encoded}"

    while [ $i -gt 0 ]; do
        local c="${url_encoded%${url_encoded#?}}"
        url_encoded="${url_encoded#?}"

        case "$c" in
            '+') decoded="${decoded} " ;;
            '%')
                local hex="${url_encoded%${url_encoded#??}}"
                url_encoded="${url_encoded#??}"
                decoded="${decoded}$(printf "\\$(printf '%03o' 0x$hex)")"
                i=$((i - 2))
                ;;
            *) decoded="${decoded}$c" ;;
        esac
        i=$((i - 1))
    done

    echo "$decoded"
}

# Extract parameter safely
extract_param() {
    local param="$1"
    # Escape dots in grep pattern
    param=$(echo "$param" | sed 's/\./\\./g')
    echo "$FORM_DATA" | grep -oE "(^|&)${param}=[^&]*" | cut -d= -f2- | head -1
}

# Validate PPPoE credentials
validate_pppoe_credentials() {
    local user="$1"
    local pwd="$2"

    # Check for empty
    if [ -z "$user" ] || [ -z "$pwd" ]; then
        return 1
    fi

    # Check length (PPPoE max is 256, but we limit for safety)
    if [ ${#user} -gt 128 ] || [ ${#pwd} -gt 128 ]; then
        log_message "VALIDATION_FAILED: Credentials too long (user: ${#user}, pwd: ${#pwd})"
        return 1
    fi

    # Validate characters - only printable ASCII
    if ! echo "$user" | grep -qE '^[[:print:]]{1,128}$'; then
        log_message "VALIDATION_FAILED: Username contains invalid characters"
        return 1
    fi

    if ! echo "$pwd" | grep -qE '^[[:print:]]{1,128}$'; then
        log_message "VALIDATION_FAILED: Password contains invalid characters"
        return 1
    fi

    return 0
}

# Check rate limiting
check_rate_limit() {
    local client_ip="${REMOTE_ADDR:-unknown}"
    local rate_file="/tmp/.wan_config_rate_${client_ip}.limit"
    local now=$(date +%s)
    local time_window=$((now - RATE_LIMIT_WINDOW))

    if [ -f "$rate_file" ]; then
        local file_time=$(stat -c %Y "$rate_file" 2>/dev/null || echo "0")

        if [ "$file_time" -gt "$time_window" ]; then
            local count=$(cat "$rate_file" 2>/dev/null || echo "0")

            if [ "$count" -ge "$RATE_LIMIT_COUNT" ]; then
                log_message "RATE_LIMIT_EXCEEDED from $client_ip"
                return 1
            fi

            echo $((count + 1)) > "$rate_file"
        else
            echo "1" > "$rate_file"
        fi
    else
        echo "1" > "$rate_file"
    fi

    return 0
}

# Safe HTTP response
output_response() {
    local status="$1"
    local body="$2"

    echo "HTTP/1.1 $status"
    echo "Content-Type: text/html; charset=utf-8"
    echo "Content-Length: ${#body}"
    echo "Cache-Control: no-store, no-cache, must-revalidate, max-age=0"
    echo "Pragma: no-cache"
    echo "Expires: 0"
    echo "X-Content-Type-Options: nosniff"
    echo "X-XSS-Protection: 1; mode=block"
    echo ""
    echo "$body"
}

# Main script
read FORM_DATA

# Check rate limiting
if ! check_rate_limit; then
    output_response "429 Too Many Requests" "<html><body><h2>Error: Too many requests</h2></body></html>"
    exit 0
fi

# Extract parameters
RAW_PPPOE_USER=$(extract_param "pppoeUser")
RAW_PPPOE_PWD=$(extract_param "pppoePass")

# Decode parameters
PPPOE_USER=$(urldecode "$RAW_PPPOE_USER")
PPPOE_PWD=$(urldecode "$RAW_PPPOE_PWD")

# Validate credentials
if ! validate_pppoe_credentials "$PPPOE_USER" "$PPPOE_PWD"; then
    log_message "INVALID_CREDENTIALS: Validation failed"
    output_response "400 Bad Request" "<html><body><h2>Error: Invalid username or password</h2></body></html>"
    exit 0
fi

log_message "Configuration update requested for user: [REDACTED] (length: ${#PPPOE_USER})"

# Create backup with secure temporary file
BACKUP_FILE="/fhcfg/WanCtlCfg.ini.bak"
TEMP_FILE=$(mktemp /fhcfg/.WanCtlCfg.XXXXXX 2>/dev/null) || {
    log_message "ERROR: Failed to create temporary file"
    output_response "500 Internal Server Error" "<html><body><h2>Error: System error</h2></body></html>"
    exit 0
}

trap "rm -f '$TEMP_FILE'" EXIT

# Backup original config
if [ -f /fhcfg/WanCtlCfg.ini ]; then
    cp /fhcfg/WanCtlCfg.ini "$BACKUP_FILE" 2>/dev/null || {
        log_message "ERROR: Failed to create backup"
        output_response "500 Internal Server Error" "<html><body><h2>Error: Backup failed</h2></body></html>"
        exit 0
    }
    chmod 600 "$BACKUP_FILE"
fi

# Update configuration
awk -v user="$PPPOE_USER" -v pwd="$PPPOE_PWD" '
BEGIN { in_wan0=0 }
/^#\[WAN0\]/ { in_wan0=1; print; next }
/^#\[WAN[1-9]\]/ { in_wan0=0 }
in_wan0 && /^pppoeUserName=/ { print "pppoeUserName=" user; next }
in_wan0 && /^pppoePwd=/ { print "pppoePwd=" pwd; next }
{ print }
' /fhcfg/WanCtlCfg.ini > "$TEMP_FILE" 2>/dev/null || {
    log_message "ERROR: Failed to update configuration"
    output_response "500 Internal Server Error" "<html><body><h2>Error: Configuration update failed</h2></body></html>"
    exit 0
}

# Verify file is not empty and has content
if [ ! -s "$TEMP_FILE" ]; then
    log_message "ERROR: Updated config file is empty"
    output_response "500 Internal Server Error" "<html><body><h2>Error: Validation failed</h2></body></html>"
    exit 0
fi

# Move temp file to config location with secure permissions
chmod 600 "$TEMP_FILE" 2>/dev/null || {
    log_message "ERROR: Failed to set file permissions"
    output_response "500 Internal Server Error" "<html><body><h2>Error: Permission error</h2></body></html>"
    exit 0
}

mv "$TEMP_FILE" /fhcfg/WanCtlCfg.ini 2>/dev/null || {
    log_message "ERROR: Failed to move config file"
    output_response "500 Internal Server Error" "<html><body><h2>Error: Move failed</h2></body></html>"
    exit 0
}

# Restart l3mng service safely
log_message "Restarting WAN configuration service"

# Kill existing process using full path
if pgrep -x "l3mng" >/dev/null 2>&1; then
    if pkill -f "^/fh/extend/l3mng" 2>/dev/null; then
        sleep 1
    fi

    # Force kill if still running
    if pgrep -x "l3mng" >/dev/null 2>&1; then
        pkill -9 -f "^/fh/extend/l3mng" 2>/dev/null || true
        sleep 1
    fi
fi

# Start service
if [ -x /fh/extend/l3mng ]; then
    /fh/extend/l3mng > /dev/null 2>&1 &
    STARTUP_PID=$!
    sleep 2

    if kill -0 "$STARTUP_PID" 2>/dev/null; then
        log_message "Configuration updated successfully"
        output_response "200 OK" "<html><body><h2>WAN Configuration Saved</h2></body></html>"
        exit 0
    else
        log_message "ERROR: Service failed to start (PID: $STARTUP_PID)"
        output_response "500 Internal Server Error" "<html><body><h2>Error: Service startup failed</h2></body></html>"
        exit 0
    fi
else
    log_message "ERROR: l3mng executable not found or not executable"
    output_response "500 Internal Server Error" "<html><body><h2>Error: Service not available</h2></body></html>"
    exit 0
fi
