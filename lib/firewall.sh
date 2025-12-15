#!/bin/bash
# Firewall management functions

# Source utils for logging
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIB_DIR/utils.sh"

detect_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        echo "ufw"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo "firewalld"
    else
        echo "none"
    fi
}

open_firewall_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local firewall_type=$(detect_firewall)
    
    if [ -z "$port" ]; then
        error "Port không được để trống"
        return 1
    fi
    
    info "Đang mở port $port/$protocol trên firewall..."
    
    case "$firewall_type" in
        ufw)
            if command -v ufw >/dev/null 2>&1; then
                # Check if ufw is active
                if ! ufw status | grep -q "Status: active"; then
                    warn "UFW chưa được kích hoạt. Đang kích hoạt..."
                    ufw --force enable
                fi
                ufw allow "$port/$protocol"
                ok "Đã mở port $port/$protocol trên UFW"
                return 0
            fi
            ;;
        firewalld)
            if command -v firewall-cmd >/dev/null 2>&1; then
                # Check if firewalld is running
                if systemctl is-active --quiet firewalld; then
                    firewall-cmd --permanent --add-port="$port/$protocol"
                    firewall-cmd --reload
                    ok "Đã mở port $port/$protocol trên firewalld"
                    return 0
                else
                    warn "Firewalld không chạy. Đang khởi động..."
                    systemctl start firewalld
                    systemctl enable firewalld
                    firewall-cmd --permanent --add-port="$port/$protocol"
                    firewall-cmd --reload
                    ok "Đã mở port $port/$protocol trên firewalld"
                    return 0
                fi
            fi
            ;;
        none)
            warn "Không phát hiện firewall tool (ufw/firewalld). Vui lòng mở port $port/$protocol thủ công nếu cần."
            return 0
            ;;
        *)
            warn "Firewall type không xác định: $firewall_type"
            return 1
            ;;
    esac
}

close_firewall_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local firewall_type=$(detect_firewall)
    
    if [ -z "$port" ]; then
        return 0
    fi
    
    info "Đang đóng port $port/$protocol trên firewall..."
    
    case "$firewall_type" in
        ufw)
            if command -v ufw >/dev/null 2>&1; then
                ufw delete allow "$port/$protocol" 2>/dev/null || true
                ok "Đã đóng port $port/$protocol trên UFW"
            fi
            ;;
        firewalld)
            if command -v firewall-cmd >/dev/null 2>&1; then
                firewall-cmd --permanent --remove-port="$port/$protocol" 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                ok "Đã đóng port $port/$protocol trên firewalld"
            fi
            ;;
        none)
            info "Không có firewall để đóng port"
            ;;
    esac
}

