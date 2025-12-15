#!/bin/bash
# Check installed proxies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/lib/utils.sh"

check_proxies() {
    info "Đang kiểm tra các proxy đã cài đặt..."
    echo ""
    
    local found_any=false
    
    # Check HTTP Proxy (Squid)
    if check_http_proxy; then
        found_any=true
    fi
    
    # Check SOCKS5 Proxy
    if check_socks5_proxy; then
        found_any=true
    fi
    
    # Check Shadowsocks
    if check_shadowsocks_proxy; then
        found_any=true
    fi
    
    if [ "$found_any" = false ]; then
        info "Không tìm thấy proxy nào đã được cài đặt."
        echo ""
    fi
}

check_http_proxy() {
    local squid_running=false
    local squid_port=""
    local squid_config="/etc/squid/squid.conf"
    
    # Check if squid service exists or config file exists
    if systemctl list-unit-files 2>/dev/null | grep -q "squid.service" || [ -f "$squid_config" ] || systemctl list-units --type=service 2>/dev/null | grep -q "squid"; then
        if systemctl is-active --quiet squid 2>/dev/null; then
            squid_running=true
        fi
        
        # Get port from config
        if [ -f "$squid_config" ]; then
            squid_port=$(grep "^http_port" "$squid_config" 2>/dev/null | awk '{print $2}' | head -n 1)
        fi
        
        # Get port from listening ports
        if [ -z "$squid_port" ]; then
            squid_port=$(ss -lntup 2>/dev/null | grep -i squid | grep -oP ':\K[0-9]+' | head -n 1 || true)
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📡 HTTP Proxy (Squid)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Status: $([ "$squid_running" = true ] && echo "✅ Đang chạy" || echo "❌ Đã dừng")"
        
        if [ -n "$squid_port" ]; then
            echo "  Port: $squid_port"
            
            # Try to get username from password file
            local passwd_file="/etc/squid/passwords"
            if [ -f "$passwd_file" ] && [ -r "$passwd_file" ]; then
                local username=$(head -n 1 "$passwd_file" 2>/dev/null | cut -d: -f1 || true)
                if [ -n "$username" ]; then
                    echo "  Username: $username"
                    echo "  Password: (đã được lưu trong config)"
                fi
            fi
            
            # Get server IP
            local server_ip=$(get_server_ip 2>/dev/null | head -n 1 | tr -d '\n\r' || echo "N/A")
            if [ -n "$server_ip" ] && [ "$server_ip" != "N/A" ]; then
                echo "  Server IP: $server_ip"
                if [ -n "$username" ]; then
                    echo "  URL: http://${username}:***@${server_ip}:${squid_port}"
                fi
            fi
        fi
        
        echo "  Service: squid"
        echo "  Config: $squid_config"
        echo ""
        return 0
    fi
    return 1
}

check_socks5_proxy() {
    local dante_running=false
    local microsocks_running=false
    local socks5_port=""
    local socks5_username=""
    local found_socks5=false
    
    # Check Dante
    if systemctl list-unit-files 2>/dev/null | grep -q "danted.service" || \
       systemctl list-units --type=service 2>/dev/null | grep -q "danted" || \
       [ -f "/etc/danted.conf" ]; then
        if systemctl is-active --quiet danted 2>/dev/null; then
            dante_running=true
        fi
        
        # Get port from config
        local dante_config="/etc/danted.conf"
        if [ -f "$dante_config" ]; then
            socks5_port=$(grep "^internal:" "$dante_config" 2>/dev/null | grep -oP 'port = \K[0-9]+' | head -n 1 || true)
        fi
        
        # Get port from listening ports (check port 6666 specifically)
        if [ -z "$socks5_port" ]; then
            socks5_port=$(ss -lntup 2>/dev/null | grep -i danted | grep -oP ':\K[0-9]+' | head -n 1 || true)
        fi
        # Also check if port 6666 is listening (common SOCKS5 port)
        if [ -z "$socks5_port" ]; then
            if ss -lntup 2>/dev/null | grep -q ":6666 "; then
                socks5_port="6666"
            fi
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔌 SOCKS5 Proxy (Dante)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Status: $([ "$dante_running" = true ] && echo "✅ Đang chạy" || echo "❌ Đã dừng")"
        
        if [ -n "$socks5_port" ]; then
            echo "  Port: $socks5_port"
        fi
        
        echo "  Service: danted"
        echo "  Config: /etc/danted.conf"
        
        # Get server IP
        local server_ip=$(get_server_ip 2>/dev/null | head -n 1 | tr -d '\n\r' || echo "N/A")
        if [ -n "$server_ip" ] && [ "$server_ip" != "N/A" ] && [ -n "$socks5_port" ]; then
            echo "  Server IP: $server_ip"
            echo "  URL: socks5://***:***@${server_ip}:${socks5_port}"
        fi
        
        echo ""
        found_socks5=true
    fi
    
    # Check microsocks
    if systemctl list-unit-files 2>/dev/null | grep -q "microsocks.service" || \
       systemctl list-units --type=service 2>/dev/null | grep -q "microsocks" || \
       [ -f "/etc/systemd/system/microsocks.service" ] || \
       [ -f "/usr/local/bin/microsocks" ]; then
        if systemctl is-active --quiet microsocks 2>/dev/null; then
            microsocks_running=true
        fi
        
        # Get port and credentials from service file
        local service_file="/etc/systemd/system/microsocks.service"
        if [ -f "$service_file" ]; then
            socks5_port=$(grep "ExecStart" "$service_file" 2>/dev/null | grep -oP '-p \K[0-9]+' | head -n 1 || true)
            socks5_username=$(grep "ExecStart" "$service_file" 2>/dev/null | grep -oP '-u \K[^ ]+' | head -n 1 || true)
        fi
        
        # Get port from listening ports
        if [ -z "$socks5_port" ]; then
            socks5_port=$(ss -lntup 2>/dev/null | grep -i microsocks | grep -oP ':\K[0-9]+' | head -n 1 || true)
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔌 SOCKS5 Proxy (microsocks)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Status: $([ "$microsocks_running" = true ] && echo "✅ Đang chạy" || echo "❌ Đã dừng")"
        
        if [ -n "$socks5_port" ]; then
            echo "  Port: $socks5_port"
        fi
        
        if [ -n "$socks5_username" ]; then
            echo "  Username: $socks5_username"
            echo "  Password: (đã được lưu trong config)"
        fi
        
        echo "  Service: microsocks"
        echo "  Config: $service_file"
        
        # Get server IP
        local server_ip=$(get_server_ip 2>/dev/null | head -n 1 | tr -d '\n\r' || echo "N/A")
        if [ -n "$server_ip" ] && [ "$server_ip" != "N/A" ] && [ -n "$socks5_port" ]; then
            echo "  Server IP: $server_ip"
            if [ -n "$socks5_username" ]; then
                echo "  URL: socks5://${socks5_username}:***@${server_ip}:${socks5_port}"
            else
                echo "  URL: socks5://***:***@${server_ip}:${socks5_port}"
            fi
        fi
        
        echo ""
        found_socks5=true
    fi
    
    if [ "$found_socks5" = true ]; then
        return 0
    fi
    return 1
}

check_shadowsocks_proxy() {
    local found_ss=false
    local ss_libev_running=false
    local ss_rust_running=false
    local ss_port=""
    local ss_method=""
    local ss_password=""
    
    # Check shadowsocks-libev
    if systemctl list-unit-files | grep -q "shadowsocks-libev.service"; then
        if systemctl is-active --quiet shadowsocks-libev 2>/dev/null; then
            ss_libev_running=true
        fi
        
        # Get config from service or config file
        local ss_config="/etc/shadowsocks-libev/config.json"
        if [ -f "$ss_config" ]; then
            ss_port=$(grep "server_port" "$ss_config" 2>/dev/null | grep -oP '[0-9]+' | head -n 1 || true)
            ss_method=$(grep "method" "$ss_config" 2>/dev/null | grep -oP '"[^"]+"' | head -n 1 | tr -d '"' || true)
            ss_password=$(grep "password" "$ss_config" 2>/dev/null | grep -oP '"[^"]+"' | head -n 1 | tr -d '"' || true)
        fi
        
        # Get port from listening ports
        if [ -z "$ss_port" ]; then
            ss_port=$(ss -lntup 2>/dev/null | grep -i shadowsocks | grep -oP ':\K[0-9]+' | head -n 1 || true)
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌙 Shadowsocks (libev)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Status: $([ "$ss_libev_running" = true ] && echo "✅ Đang chạy" || echo "❌ Đã dừng")"
        
        if [ -n "$ss_port" ]; then
            echo "  Port: $ss_port"
        fi
        
        if [ -n "$ss_method" ]; then
            echo "  Method: $ss_method"
        fi
        
        if [ -n "$ss_password" ]; then
            echo "  Password: $(mask_password "$ss_password")"
        fi
        
        echo "  Service: shadowsocks-libev"
        echo "  Config: $ss_config"
        
        # Get server IP
        local server_ip=$(get_server_ip 2>/dev/null | head -n 1 | tr -d '\n\r' || echo "N/A")
        if [ -n "$server_ip" ] && [ "$server_ip" != "N/A" ] && [ -n "$ss_port" ] && [ -n "$ss_method" ] && [ -n "$ss_password" ]; then
            echo "  Server IP: $server_ip"
            local ss_uri=$(generate_ss_uri "$server_ip" "$ss_port" "$ss_password" "$ss_method" 2>/dev/null || echo "")
            if [ -n "$ss_uri" ]; then
                echo "  SS URI: $ss_uri"
            fi
        fi
        
        echo ""
        found_ss=true
    fi
    
    # Check shadowsocks-rust
    if systemctl list-unit-files 2>/dev/null | grep -q "shadowsocks-rust.service" || \
       systemctl list-units --type=service 2>/dev/null | grep -q "shadowsocks-rust" || \
       [ -f "/etc/shadowsocks-rust/config.json" ] || \
       [ -f "/etc/systemd/system/shadowsocks-rust.service" ] || \
       [ -f "/usr/local/bin/ss-server" ]; then
        if systemctl is-active --quiet shadowsocks-rust 2>/dev/null; then
            ss_rust_running=true
        fi
        
        # Get config from service or config file
        local ss_config="/etc/shadowsocks-rust/config.json"
        if [ -f "$ss_config" ]; then
            ss_port=$(grep "server_port" "$ss_config" 2>/dev/null | grep -oP '[0-9]+' | head -n 1 || true)
            ss_method=$(grep "method" "$ss_config" 2>/dev/null | grep -oP '"[^"]+"' | head -n 1 | tr -d '"' || true)
            ss_password=$(grep "password" "$ss_config" 2>/dev/null | grep -oP '"[^"]+"' | head -n 1 | tr -d '"' || true)
        fi
        
        # Get port from listening ports
        if [ -z "$ss_port" ]; then
            ss_port=$(ss -lntup 2>/dev/null | grep -i shadowsocks | grep -oP ':\K[0-9]+' | head -n 1 || true)
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌙 Shadowsocks (rust)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Status: $([ "$ss_rust_running" = true ] && echo "✅ Đang chạy" || echo "❌ Đã dừng")"
        
        if [ -n "$ss_port" ]; then
            echo "  Port: $ss_port"
        fi
        
        if [ -n "$ss_method" ]; then
            echo "  Method: $ss_method"
        fi
        
        if [ -n "$ss_password" ]; then
            echo "  Password: $(mask_password "$ss_password")"
        fi
        
        echo "  Service: shadowsocks-rust"
        echo "  Config: $ss_config"
        
        # Get server IP
        local server_ip=$(get_server_ip 2>/dev/null | head -n 1 | tr -d '\n\r' || echo "N/A")
        if [ -n "$server_ip" ] && [ "$server_ip" != "N/A" ] && [ -n "$ss_port" ] && [ -n "$ss_method" ] && [ -n "$ss_password" ]; then
            echo "  Server IP: $server_ip"
            local ss_uri=$(generate_ss_uri "$server_ip" "$ss_port" "$ss_password" "$ss_method" 2>/dev/null || echo "")
            if [ -n "$ss_uri" ]; then
                echo "  SS URI: $ss_uri"
            fi
        fi
        
        echo ""
        found_ss=true
    fi
    
    if [ "$found_ss" = true ]; then
        return 0
    fi
    return 1
}

# Note: generate_ss_uri function should be available from shadowsocks.sh
# which is already sourced in main script

