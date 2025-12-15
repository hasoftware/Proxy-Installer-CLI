#!/bin/bash
# Utility functions for auto-proxy-installer

# Logging functions
log_file="/var/log/auto-proxy-installer.log"
log_dir="/var/log"

# Ensure log directory exists
mkdir -p "$log_dir"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

info() {
    echo "[INFO] $*"
    log "INFO" "$*"
}

warn() {
    echo "[WARN] $*" >&2
    log "WARN" "$*"
}

error() {
    echo "[ERROR] $*" >&2
    log "ERROR" "$*"
}

ok() {
    echo "[OK] $*"
    log "OK" "$*"
}

# Mask password in output
mask_password() {
    local password="$1"
    if [ ${#password} -le 4 ]; then
        echo "****"
    else
        echo "${password:0:2}****${password: -2}"
    fi
}

# Validate port number
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        error "Port phải là số"
        return 1
    fi
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error "Port phải trong khoảng 1-65535"
        return 1
    fi
    return 0
}

# Check if port is in use
is_port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        if ss -lntup 2>/dev/null | grep -q ":$port "; then
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -lntup 2>/dev/null | grep -q ":$port "; then
            return 0
        fi
    fi
    return 1
}

# Validate username (no spaces, not empty)
validate_username() {
    local username="$1"
    if [ -z "$username" ]; then
        error "Username không được để trống"
        return 1
    fi
    if [[ "$username" =~ [[:space:]] ]]; then
        error "Username không được chứa khoảng trắng"
        return 1
    fi
    return 0
}

# Validate password (min 6 characters)
validate_password() {
    local password="$1"
    if [ ${#password} -lt 6 ]; then
        error "Password phải có ít nhất 6 ký tự"
        return 1
    fi
    return 0
}

# Generate random password
generate_random_password() {
    local length="${1:-16}"
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    elif command -v pwgen >/dev/null 2>&1; then
        pwgen -s "$length" 1
    else
        # Fallback: use /dev/urandom
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    fi
}

# Get public IP
get_public_ip() {
    local ip=""
    
    # Try api.ipify.org first
    if command -v curl >/dev/null 2>&1; then
        ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || true)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    fi
    
    # Fallback to ifconfig.me
    if command -v curl >/dev/null 2>&1; then
        ip=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || true)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    fi
    
    # Fallback to icanhazip.com
    if command -v curl >/dev/null 2>&1; then
        ip=$(curl -s --max-time 5 https://icanhazip.com 2>/dev/null || true)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    fi
    
    return 1
}

# Prompt for IP if auto-detect fails
prompt_for_ip() {
    local ip=""
    while true; do
        read -p "Nhập địa chỉ IP công cộng của server: " ip
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        else
            error "Địa chỉ IP không hợp lệ. Vui lòng nhập lại."
        fi
    done
}

# Get server IP (auto-detect or prompt)
# Returns only the IP address, no logging
# Redirect stderr to prevent any error messages from being captured
get_server_ip() {
    local ip=""
    ip=$(get_public_ip 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    else
        # If auto-detect fails, prompt user (but don't capture error messages)
        ip=$(prompt_for_ip 2>/dev/null)
        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    fi
    return 1
}

# Read input with default value
read_with_default() {
    local prompt="$1"
    local default="$2"
    local value=""
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        echo "${value:-$default}"
    else
        read -p "$prompt: " value
        echo "$value"
    fi
}

# Confirm action
confirm() {
    local message="$1"
    local response=""
    while true; do
        read -p "$message (Y/n): " response
        case "${response,,}" in
            y|yes|"")
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                warn "Vui lòng nhập Y hoặc N"
                ;;
        esac
    done
}

