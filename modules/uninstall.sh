#!/bin/bash
# Uninstall proxy modules

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/lib/utils.sh"
. "$SCRIPT_DIR/lib/os_detect.sh"
. "$SCRIPT_DIR/lib/firewall.sh"

uninstall_proxy() {
    local proxy_type="$1"
    
    info "Bắt đầu gỡ cài đặt $proxy_type proxy..."
    
    case "$proxy_type" in
        http)
            uninstall_http_proxy
            ;;
        socks5)
            uninstall_socks5_proxy
            ;;
        shadowsocks)
            uninstall_shadowsocks
            ;;
        all)
            uninstall_all_proxies
            ;;
        *)
            error "Loại proxy không hợp lệ: $proxy_type"
            return 1
            ;;
    esac
}

uninstall_http_proxy() {
    info "Gỡ cài đặt HTTP Proxy (Squid)..."
    
    # Get port from config
    local port=""
    if [ -f /etc/squid/squid.conf ]; then
        port=$(grep "^http_port" /etc/squid/squid.conf | awk '{print $2}' | head -n 1)
    fi
    
    # Stop and disable service
    if systemctl is-active --quiet squid; then
        systemctl stop squid
    fi
    systemctl disable squid 2>/dev/null || true
    
    # Close firewall port
    if [ -n "$port" ]; then
        close_firewall_port "$port" "tcp"
    fi
    
    # Remove password file
    if [ -f /etc/squid/passwords ]; then
        rm -f /etc/squid/passwords
        ok "Đã xóa password file"
    fi
    
    # Restore original config if backup exists
    local squid_conf="/etc/squid/squid.conf"
    local backups=$(ls -t "${squid_conf}.backup."* 2>/dev/null | head -n 1)
    if [ -n "$backups" ] && [ -f "$backups" ]; then
        if confirm "Khôi phục cấu hình Squid gốc?"; then
            cp "$backups" "$squid_conf"
            ok "Đã khôi phục cấu hình gốc"
        fi
    fi
    
    # Ask if user wants to remove package
    if confirm "Bạn có muốn gỡ package squid?"; then
        # Detect package manager
        local os_id=$(detect_os)
        local pkg_manager=$(detect_package_manager "$os_id")
        
        case "$pkg_manager" in
            apt|apt-get)
                apt remove -y squid apache2-utils 2>/dev/null || true
                ;;
            yum|dnf)
                yum remove -y squid httpd-tools 2>/dev/null || dnf remove -y squid httpd-tools 2>/dev/null || true
                ;;
        esac
        ok "Đã gỡ package squid"
    fi
    
    # Remove from state
    remove_proxy_state "http"
    
    ok "Đã gỡ cài đặt HTTP Proxy"
}

uninstall_socks5_proxy() {
    info "Gỡ cài đặt SOCKS5 Proxy..."
    
    # Check if using dante or microsocks
    local using_dante=false
    local using_microsocks=false
    
    if systemctl list-units --type=service | grep -q "danted.service"; then
        using_dante=true
    fi
    
    if systemctl list-units --type=service | grep -q "microsocks.service"; then
        using_microsocks=true
    fi
    
    if [ "$using_dante" = true ]; then
        # Get port from config
        local port=""
        if [ -f /etc/danted.conf ]; then
            port=$(grep "^internal:" /etc/danted.conf | grep -oP 'port = \K[0-9]+' | head -n 1)
        fi
        
        # Stop and disable dante
        if systemctl is-active --quiet danted; then
            systemctl stop danted
        fi
        systemctl disable danted 2>/dev/null || true
        
        # Close firewall port
        if [ -n "$port" ]; then
            close_firewall_port "$port" "tcp"
        fi
        
        # Restore original config if backup exists
        local dante_conf="/etc/danted.conf"
        local backups=$(ls -t "${dante_conf}.backup."* 2>/dev/null | head -n 1)
        if [ -n "$backups" ] && [ -f "$backups" ]; then
            if confirm "Khôi phục cấu hình Dante gốc?"; then
                cp "$backups" "$dante_conf"
                ok "Đã khôi phục cấu hình gốc"
            fi
        fi
        
        # Ask if user wants to remove package
        if confirm "Bạn có muốn gỡ package dante?"; then
            local os_id=$(detect_os)
            local pkg_manager=$(detect_package_manager "$os_id")
            
            case "$pkg_manager" in
                apt|apt-get)
                    apt remove -y dante-server 2>/dev/null || true
                    ;;
                yum|dnf)
                    yum remove -y dante 2>/dev/null || dnf remove -y dante 2>/dev/null || true
                    ;;
            esac
            ok "Đã gỡ package dante"
        fi
    fi
    
    if [ "$using_microsocks" = true ]; then
        # Get port from service file
        local port=""
        if [ -f /etc/systemd/system/microsocks.service ]; then
            port=$(grep "ExecStart" /etc/systemd/system/microsocks.service | grep -oP '-p \K[0-9]+' | head -n 1)
        fi
        
        # Stop and disable microsocks
        if systemctl is-active --quiet microsocks; then
            systemctl stop microsocks
        fi
        systemctl disable microsocks 2>/dev/null || true
        
        # Close firewall port
        if [ -n "$port" ]; then
            close_firewall_port "$port" "tcp"
        fi
        
        # Remove service file
        if [ -f /etc/systemd/system/microsocks.service ]; then
            rm -f /etc/systemd/system/microsocks.service
            ok "Đã xóa microsocks service file"
        fi
        
        # Remove binary (optional)
        if confirm "Bạn có muốn xóa binary microsocks?"; then
            rm -f /usr/local/bin/microsocks
            ok "Đã xóa microsocks binary"
        fi
        
        # Remove password file
        if [ -f /etc/microsocks/passwd ]; then
            rm -f /etc/microsocks/passwd
            ok "Đã xóa password file"
        fi
    fi
    
    systemctl daemon-reload
    
    # Remove from state
    remove_proxy_state "socks5"
    
    ok "Đã gỡ cài đặt SOCKS5 Proxy"
}

uninstall_shadowsocks() {
    info "Gỡ cài đặt Shadowsocks..."
    
    # Check if using libev or rust
    local using_libev=false
    local using_rust=false
    
    if systemctl list-units --type=service | grep -q "shadowsocks-libev.service"; then
        using_libev=true
    fi
    
    if systemctl list-units --type=service | grep -q "shadowsocks-rust.service"; then
        using_rust=true
    fi
    
    if [ "$using_libev" = true ]; then
        # Get port from config
        local port=""
        if [ -f /etc/shadowsocks-libev/config.json ]; then
            port=$(grep "server_port" /etc/shadowsocks-libev/config.json | grep -oP '[0-9]+' | head -n 1)
        fi
        
        # Stop and disable shadowsocks-libev
        if systemctl is-active --quiet shadowsocks-libev; then
            systemctl stop shadowsocks-libev
        fi
        systemctl disable shadowsocks-libev 2>/dev/null || true
        
        # Close firewall ports
        if [ -n "$port" ]; then
            close_firewall_port "$port" "tcp"
            close_firewall_port "$port" "udp"
        fi
        
        # Remove config
        if [ -f /etc/shadowsocks-libev/config.json ]; then
            rm -f /etc/shadowsocks-libev/config.json
            ok "Đã xóa config file"
        fi
        
        # Ask if user wants to remove package
        if confirm "Bạn có muốn gỡ package shadowsocks-libev?"; then
            local os_id=$(detect_os)
            local pkg_manager=$(detect_package_manager "$os_id")
            
            case "$pkg_manager" in
                apt|apt-get)
                    apt remove -y shadowsocks-libev 2>/dev/null || true
                    ;;
                yum|dnf)
                    yum remove -y shadowsocks-libev 2>/dev/null || dnf remove -y shadowsocks-libev 2>/dev/null || true
                    ;;
            esac
            ok "Đã gỡ package shadowsocks-libev"
        fi
    fi
    
    if [ "$using_rust" = true ]; then
        # Get port from config
        local port=""
        if [ -f /etc/shadowsocks-rust/config.json ]; then
            port=$(grep "server_port" /etc/shadowsocks-rust/config.json | grep -oP '[0-9]+' | head -n 1)
        fi
        
        # Stop and disable shadowsocks-rust
        if systemctl is-active --quiet shadowsocks-rust; then
            systemctl stop shadowsocks-rust
        fi
        systemctl disable shadowsocks-rust 2>/dev/null || true
        
        # Close firewall ports
        if [ -n "$port" ]; then
            close_firewall_port "$port" "tcp"
            close_firewall_port "$port" "udp"
        fi
        
        # Remove service file
        if [ -f /etc/systemd/system/shadowsocks-rust.service ]; then
            rm -f /etc/systemd/system/shadowsocks-rust.service
            ok "Đã xóa shadowsocks-rust service file"
        fi
        
        # Remove config
        if [ -f /etc/shadowsocks-rust/config.json ]; then
            rm -f /etc/shadowsocks-rust/config.json
            ok "Đã xóa config file"
        fi
        
        # Remove binary (optional)
        if confirm "Bạn có muốn xóa binary shadowsocks-rust?"; then
            rm -f /usr/local/bin/ss-server
            ok "Đã xóa shadowsocks-rust binary"
        fi
    fi
    
    systemctl daemon-reload
    
    # Remove from state
    remove_proxy_state "shadowsocks"
    
    ok "Đã gỡ cài đặt Shadowsocks"
}

uninstall_all_proxies() {
    info "Gỡ cài đặt tất cả proxies..."
    
    local state_file="/etc/auto-proxy-installer/installed_proxies.txt"
    if [ ! -f "$state_file" ]; then
        warn "Không tìm thấy file state. Không có proxy nào được cài đặt."
        return 0
    fi
    
    # Get unique proxy types
    local proxy_types=$(cut -d'|' -f1 "$state_file" | sort -u)
    
    for proxy_type in $proxy_types; do
        case "$proxy_type" in
            http)
                uninstall_http_proxy
                ;;
            socks5)
                uninstall_socks5_proxy
                ;;
            shadowsocks)
                uninstall_shadowsocks
                ;;
        esac
    done
    
    # Clean up state directory
    if confirm "Bạn có muốn xóa toàn bộ thư mục cấu hình?"; then
        rm -rf /etc/auto-proxy-installer
        ok "Đã xóa thư mục cấu hình"
    fi
    
    ok "Đã gỡ cài đặt tất cả proxies"
}

remove_proxy_state() {
    local proxy_type="$1"
    local state_file="/etc/auto-proxy-installer/installed_proxies.txt"
    
    if [ -f "$state_file" ]; then
        # Remove lines matching proxy type
        grep -v "^${proxy_type}|" "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
    fi
}

