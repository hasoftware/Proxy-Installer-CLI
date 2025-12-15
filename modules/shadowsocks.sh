#!/bin/bash
# Shadowsocks installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SCRIPT_DIR/lib/utils.sh"
. "$SCRIPT_DIR/lib/pkg.sh"
. "$SCRIPT_DIR/lib/firewall.sh"

install_shadowsocks() {
    local port="$1"
    local password="$2"
    local method="$3"
    local pkg_manager="$4"
    
    info "Bắt đầu cài đặt Shadowsocks..."
    
    # Validate inputs
    if ! validate_port "$port"; then
        return 1
    fi
    
    if is_port_in_use "$port"; then
        error "Port $port đang được sử dụng"
        return 1
    fi
    
    if ! validate_password "$password"; then
        return 1
    fi
    
    # Validate method
    case "$method" in
        aes-256-gcm|chacha20-ietf-poly1305|aes-128-gcm)
            ;;
        *)
            error "Method không hợp lệ: $method"
            return 1
            ;;
    esac
    
    # Try to install shadowsocks-libev first
    local ss_pkg=""
    local use_libev=false
    
    case "$pkg_manager" in
        apt|apt-get)
            ss_pkg="shadowsocks-libev"
            ;;
        yum|dnf)
            # Check if shadowsocks-libev is available
            ss_pkg="shadowsocks-libev"
            ;;
    esac
    
    if [ -n "$ss_pkg" ] && check_package_available "$pkg_manager" "$ss_pkg"; then
        info "Tìm thấy shadowsocks-libev, đang cài đặt..."
        if install_packages "$pkg_manager" "$ss_pkg"; then
            use_libev=true
        fi
    fi
    
    if [ "$use_libev" = true ]; then
        install_shadowsocks_libev "$port" "$password" "$method" "$pkg_manager"
    else
        warn "shadowsocks-libev không có sẵn, sử dụng shadowsocks-rust..."
        install_shadowsocks_rust "$port" "$password" "$method" "$pkg_manager"
    fi
}

install_shadowsocks_libev() {
    local port="$1"
    local password="$2"
    local method="$3"
    local pkg_manager="$4"
    
    info "Cài đặt Shadowsocks với shadowsocks-libev..."
    
    # Create config directory
    local config_dir="/etc/shadowsocks-libev"
    mkdir -p "$config_dir"
    
    # Create config file
    local config_file="$config_dir/config.json"
    cat > "$config_file" <<EOF
{
    "server": "0.0.0.0",
    "server_port": $port,
    "password": "$password",
    "method": "$method",
    "mode": "tcp_and_udp",
    "fast_open": false
}
EOF
    
    chmod 600 "$config_file"
    chown root:root "$config_file"
    
    # Backup original service file if exists
    local service_file="/etc/systemd/system/shadowsocks-libev.service"
    if [ -f "$service_file" ]; then
        cp "$service_file" "${service_file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create or update systemd service
    cat > "$service_file" <<EOF
[Unit]
Description=Shadowsocks-libev Default Server Service
Documentation=man:ss-server(1)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-server -c $config_file
Restart=on-failure
RestartSec=10s
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
EOF
    
    # Open firewall port
    open_firewall_port "$port" "tcp"
    open_firewall_port "$port" "udp"
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable shadowsocks-libev
    if systemctl restart shadowsocks-libev; then
        ok "Đã khởi động shadowsocks-libev service"
    else
        error "Không thể khởi động shadowsocks-libev service"
        error "Kiểm tra log: journalctl -u shadowsocks-libev -n 50"
        return 1
    fi
    
    # Save state
    save_proxy_state "shadowsocks" "$port" "$password" "$method"
    
    ok "Shadowsocks (libev) đã được cài đặt thành công!"
    return 0
}

install_shadowsocks_rust() {
    local port="$1"
    local password="$2"
    local method="$3"
    local pkg_manager="$4"
    
    info "Cài đặt Shadowsocks với shadowsocks-rust..."
    
    # Detect architecture
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            local rust_arch="x86_64"
            ;;
        aarch64|arm64)
            local rust_arch="aarch64"
            ;;
        *)
            error "Architecture không được hỗ trợ: $arch"
            return 1
            ;;
    esac
    
    # Download shadowsocks-rust binary
    local latest_version="1.17.0"  # Update as needed
    local download_url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${latest_version}/shadowsocks-v${latest_version}.${rust_arch}-unknown-linux-gnu.tar.xz"
    local temp_dir=$(mktemp -d)
    local bin_dir="/usr/local/bin"
    
    info "Đang tải shadowsocks-rust..."
    cd "$temp_dir" || {
        error "Không thể tạo temp directory"
        return 1
    }
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o shadowsocks.tar.xz "$download_url" || {
            error "Không thể tải shadowsocks-rust"
            cd - >/dev/null
            rm -rf "$temp_dir"
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -O shadowsocks.tar.xz "$download_url" || {
            error "Không thể tải shadowsocks-rust"
            cd - >/dev/null
            rm -rf "$temp_dir"
            return 1
        }
    else
        error "Cần curl hoặc wget để tải shadowsocks-rust"
        cd - >/dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract
    if command -v tar >/dev/null 2>&1; then
        tar -xf shadowsocks.tar.xz || {
            error "Không thể giải nén shadowsocks-rust"
            cd - >/dev/null
            rm -rf "$temp_dir"
            return 1
        }
    else
        error "Cần tar để giải nén"
        cd - >/dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Find ss-server binary
    local ss_binary=$(find . -name "ssserver" -o -name "ss-server" | head -n 1)
    if [ -z "$ss_binary" ] || [ ! -f "$ss_binary" ]; then
        error "Không tìm thấy ss-server binary"
        cd - >/dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install binary
    cp "$ss_binary" "$bin_dir/ss-server"
    chmod +x "$bin_dir/ss-server"
    chown root:root "$bin_dir/ss-server"
    
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    ok "Đã cài đặt shadowsocks-rust binary"
    
    # Create config directory
    local config_dir="/etc/shadowsocks-rust"
    mkdir -p "$config_dir"
    
    # Create config file
    local config_file="$config_dir/config.json"
    cat > "$config_file" <<EOF
{
    "server": "0.0.0.0",
    "server_port": $port,
    "password": "$password",
    "method": "$method",
    "mode": "tcp_and_udp",
    "fast_open": false
}
EOF
    
    chmod 600 "$config_file"
    chown root:root "$config_file"
    
    # Create systemd service
    local service_file="/etc/systemd/system/shadowsocks-rust.service"
    cat > "$service_file" <<EOF
[Unit]
Description=Shadowsocks-rust Server Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$bin_dir/ss-server -c $config_file
Restart=on-failure
RestartSec=10s
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
EOF
    
    # Open firewall port
    open_firewall_port "$port" "tcp"
    open_firewall_port "$port" "udp"
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable shadowsocks-rust
    if systemctl restart shadowsocks-rust; then
        ok "Đã khởi động shadowsocks-rust service"
    else
        error "Không thể khởi động shadowsocks-rust service"
        error "Kiểm tra log: journalctl -u shadowsocks-rust -n 50"
        return 1
    fi
    
    # Save state
    save_proxy_state "shadowsocks" "$port" "$password" "$method"
    
    ok "Shadowsocks (rust) đã được cài đặt thành công!"
    return 0
}

generate_ss_uri() {
    local server="$1"
    local port="$2"
    local password="$3"
    local method="$4"
    
    # Create ss:// URI
    # Format: ss://base64(method:password)@server:port
    local encoded=$(echo -n "${method}:${password}" | base64 -w 0 2>/dev/null || echo -n "${method}:${password}" | base64 | tr -d '\n')
    echo "ss://${encoded}@${server}:${port}"
}

save_proxy_state() {
    local proxy_type="$1"
    local port="$2"
    local password="$3"
    local method="$4"
    
    local state_dir="/etc/auto-proxy-installer"
    mkdir -p "$state_dir"
    
    # Don't save password in state file
    local simple_state="$state_dir/installed_proxies.txt"
    echo "$proxy_type|$port|$method|$(date +%Y-%m-%d)" >> "$simple_state"
}

