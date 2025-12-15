#!/bin/bash
# Auto Proxy Installer - Main Script
# Tự động phát hiện distro Linux và cài proxy theo lựa chọn

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
. "$SCRIPT_DIR/lib/utils.sh"
. "$SCRIPT_DIR/lib/os_detect.sh"
. "$SCRIPT_DIR/lib/pkg.sh"
. "$SCRIPT_DIR/lib/firewall.sh"

# Source modules
. "$SCRIPT_DIR/modules/http_squid.sh"
. "$SCRIPT_DIR/modules/socks5.sh"
. "$SCRIPT_DIR/modules/shadowsocks.sh"
. "$SCRIPT_DIR/modules/uninstall.sh"

# Global variables
OS_ID=""
PKG_MANAGER=""
SERVER_IP=""

# Check root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Script này cần quyền root để chạy"
        info "Vui lòng chạy: sudo $0"
        exit 1
    fi
}

# Initialize system
init_system() {
    info "Đang khởi tạo hệ thống..."
    
    # Detect OS
    local os_info=$(get_os_info)
    eval "$os_info"
    
    if [ -z "$OS_ID" ] || [ "$OS_ID" = "unknown" ]; then
        error "Không thể phát hiện hệ điều hành"
        exit 1
    fi
    
    if [ -z "$PKG_MANAGER" ] || [ "$PKG_MANAGER" = "unknown" ]; then
        error "Không thể phát hiện package manager"
        exit 1
    fi
    
    info "Đã phát hiện: OS=$OS_ID, Package Manager=$PKG_MANAGER"
    
    # Get server IP
    SERVER_IP=$(get_server_ip)
    info "Server IP: $SERVER_IP"
}

# Interactive menu
show_menu() {
    # Clear screen if possible
    clear 2>/dev/null || true
    
    echo ""
    echo "=========================================="
    echo "  Auto Proxy Installer"
    echo "=========================================="
    echo ""
    echo "Vui lòng chọn một trong các tùy chọn sau:"
    echo ""
    echo "  1. Cài Proxy HTTP"
    echo "  2. Cài Proxy SOCKS5"
    echo "  3. Cài Shadowsocks (cho Shadowrocket)"
    echo "  4. Gỡ cài đặt"
    echo "  5. Thoát"
    echo ""
    echo "=========================================="
}

# Install HTTP Proxy (interactive)
install_http_interactive() {
    info "=== Cài đặt HTTP Proxy ==="
    
    # Get port
    local port=""
    while true; do
        read -p "Nhập port (1-65535): " port
        if validate_port "$port"; then
            if is_port_in_use "$port"; then
                error "Port $port đang được sử dụng"
            else
                break
            fi
        fi
    done
    
    # Get username
    local username=""
    while true; do
        read -p "Nhập username: " username
        if validate_username "$username"; then
            break
        fi
    done
    
    # Get password
    local password=""
    while true; do
        read -p "Nhập password (hoặc 'random' để tự tạo): " password
        if [ "$password" = "random" ]; then
            password=$(generate_random_password 16)
            info "Password đã được tạo: $(mask_password "$password")"
            break
        elif validate_password "$password"; then
            break
        fi
    done
    
    # Confirm
    echo ""
    info "Cấu hình HTTP Proxy:"
    echo "  Port: $port"
    echo "  Username: $username"
    echo "  Password: $(mask_password "$password")"
    echo ""
    
    if ! confirm "Xác nhận cài đặt?"; then
        info "Đã hủy cài đặt"
        return 1
    fi
    
    # Install
    if install_http_proxy "$port" "$username" "$password" "$PKG_MANAGER"; then
        echo ""
        ok "=== Cài đặt thành công! ==="
        echo ""
        echo "Thông tin kết nối:"
        echo "  URL: http://${username}:${password}@${SERVER_IP}:${port}"
        echo ""
        echo "Kiểm tra service:"
        echo "  systemctl status squid"
        echo ""
        echo "Test proxy:"
        echo "  curl -x http://${username}:${password}@${SERVER_IP}:${port} https://api.ipify.org"
        echo ""
    else
        error "Cài đặt thất bại"
        return 1
    fi
}

# Install SOCKS5 Proxy (interactive)
install_socks5_interactive() {
    info "=== Cài đặt SOCKS5 Proxy ==="
    
    # Get port
    local port=""
    while true; do
        read -p "Nhập port (1-65535): " port
        if validate_port "$port"; then
            if is_port_in_use "$port"; then
                error "Port $port đang được sử dụng"
            else
                break
            fi
        fi
    done
    
    # Get username
    local username=""
    while true; do
        read -p "Nhập username: " username
        if validate_username "$username"; then
            break
        fi
    done
    
    # Get password
    local password=""
    while true; do
        read -p "Nhập password (hoặc 'random' để tự tạo): " password
        if [ "$password" = "random" ]; then
            password=$(generate_random_password 16)
            info "Password đã được tạo: $(mask_password "$password")"
            break
        elif validate_password "$password"; then
            break
        fi
    done
    
    # Confirm
    echo ""
    info "Cấu hình SOCKS5 Proxy:"
    echo "  Port: $port"
    echo "  Username: $username"
    echo "  Password: $(mask_password "$password")"
    echo ""
    
    if ! confirm "Xác nhận cài đặt?"; then
        info "Đã hủy cài đặt"
        return 1
    fi
    
    # Install
    if install_socks5_proxy "$port" "$username" "$password" "$PKG_MANAGER"; then
        echo ""
        ok "=== Cài đặt thành công! ==="
        echo ""
        echo "Thông tin kết nối:"
        echo "  URL: socks5://${username}:${password}@${SERVER_IP}:${port}"
        echo ""
        echo "Kiểm tra service:"
        if systemctl list-units --type=service | grep -q "danted.service"; then
            echo "  systemctl status danted"
        else
            echo "  systemctl status microsocks"
        fi
        echo ""
        echo "Test proxy (cần tool hỗ trợ SOCKS5 như curl với --socks5):"
        echo "  curl --socks5 ${username}:${password}@${SERVER_IP}:${port} https://api.ipify.org"
        echo ""
    else
        error "Cài đặt thất bại"
        return 1
    fi
}

# Install Shadowsocks (interactive)
install_shadowsocks_interactive() {
    info "=== Cài đặt Shadowsocks ==="
    
    # Get port
    local port=""
    while true; do
        read -p "Nhập port (1-65535): " port
        if validate_port "$port"; then
            if is_port_in_use "$port"; then
                error "Port $port đang được sử dụng"
            else
                break
            fi
        fi
    done
    
    # Get password
    local password=""
    while true; do
        read -p "Nhập password (hoặc 'random' để tự tạo): " password
        if [ "$password" = "random" ]; then
            password=$(generate_random_password 16)
            info "Password đã được tạo: $(mask_password "$password")"
            break
        elif validate_password "$password"; then
            break
        fi
    done
    
    # Get method
    local method=""
    echo ""
    echo "Chọn encryption method:"
    echo "1. aes-256-gcm (khuyến nghị)"
    echo "2. chacha20-ietf-poly1305"
    echo "3. aes-128-gcm"
    echo ""
    while true; do
        read -p "Chọn method [1-3] (mặc định: 1): " method_choice
        case "${method_choice:-1}" in
            1)
                method="aes-256-gcm"
                break
                ;;
            2)
                method="chacha20-ietf-poly1305"
                break
                ;;
            3)
                method="aes-128-gcm"
                break
                ;;
            *)
                warn "Lựa chọn không hợp lệ"
                ;;
        esac
    done
    
    # Confirm
    echo ""
    info "Cấu hình Shadowsocks:"
    echo "  Server: $SERVER_IP"
    echo "  Port: $port"
    echo "  Password: $(mask_password "$password")"
    echo "  Method: $method"
    echo ""
    
    if ! confirm "Xác nhận cài đặt?"; then
        info "Đã hủy cài đặt"
        return 1
    fi
    
    # Install
    if install_shadowsocks "$port" "$password" "$method" "$PKG_MANAGER"; then
        echo ""
        ok "=== Cài đặt thành công! ==="
        echo ""
        echo "Thông tin kết nối Shadowrocket:"
        echo "  Server: $SERVER_IP"
        echo "  Port: $port"
        echo "  Password: $password"
        echo "  Method: $method"
        echo ""
        
        # Generate SS URI
        if command -v base64 >/dev/null 2>&1; then
            local ss_uri=$(generate_ss_uri "$SERVER_IP" "$port" "$password" "$method")
            echo "  SS URI: $ss_uri"
            echo ""
        fi
        
        echo "Kiểm tra service:"
        if systemctl list-units --type=service | grep -q "shadowsocks-libev.service"; then
            echo "  systemctl status shadowsocks-libev"
        else
            echo "  systemctl status shadowsocks-rust"
        fi
        echo ""
    else
        error "Cài đặt thất bại"
        return 1
    fi
}

# Uninstall menu (interactive)
uninstall_interactive() {
    info "=== Gỡ cài đặt Proxy ==="
    
    echo ""
    echo "Chọn loại proxy cần gỡ:"
    echo "1. HTTP Proxy"
    echo "2. SOCKS5 Proxy"
    echo "3. Shadowsocks"
    echo "4. Tất cả"
    echo "5. Hủy"
    echo ""
    
    local choice=""
    read -p "Chọn [1-5]: " choice
    
    case "$choice" in
        1)
            if confirm "Xác nhận gỡ cài đặt HTTP Proxy?"; then
                uninstall_proxy "http"
            fi
            ;;
        2)
            if confirm "Xác nhận gỡ cài đặt SOCKS5 Proxy?"; then
                uninstall_proxy "socks5"
            fi
            ;;
        3)
            if confirm "Xác nhận gỡ cài đặt Shadowsocks?"; then
                uninstall_proxy "shadowsocks"
            fi
            ;;
        4)
            if confirm "Xác nhận gỡ cài đặt TẤT CẢ proxies?"; then
                uninstall_proxy "all"
            fi
            ;;
        5)
            info "Đã hủy"
            ;;
        *)
            error "Lựa chọn không hợp lệ"
            ;;
    esac
}

# Non-interactive mode
non_interactive_mode() {
    local proxy_type="$1"
    shift
    
    case "$proxy_type" in
        http)
            local port="$1"
            local username="$2"
            local password="$3"
            
            if [ -z "$port" ] || [ -z "$username" ] || [ -z "$password" ]; then
                error "Thiếu tham số cho HTTP proxy"
                error "Usage: $0 --http <port> <username> <password>"
                exit 1
            fi
            
            install_http_proxy "$port" "$username" "$password" "$PKG_MANAGER"
            ;;
        socks5)
            local port="$1"
            local username="$2"
            local password="$3"
            
            if [ -z "$port" ] || [ -z "$username" ] || [ -z "$password" ]; then
                error "Thiếu tham số cho SOCKS5 proxy"
                error "Usage: $0 --socks5 <port> <username> <password>"
                exit 1
            fi
            
            install_socks5_proxy "$port" "$username" "$password" "$PKG_MANAGER"
            ;;
        shadowsocks|ss)
            local port="$1"
            local password="$2"
            local method="${3:-aes-256-gcm}"
            
            if [ -z "$port" ] || [ -z "$password" ]; then
                error "Thiếu tham số cho Shadowsocks"
                error "Usage: $0 --shadowsocks <port> <password> [method]"
                exit 1
            fi
            
            install_shadowsocks "$port" "$password" "$method" "$PKG_MANAGER"
            ;;
        uninstall)
            local proxy_type_uninstall="${1:-all}"
            uninstall_proxy "$proxy_type_uninstall"
            ;;
        *)
            error "Loại proxy không hợp lệ: $proxy_type"
            exit 1
            ;;
    esac
}

# Show usage
show_usage() {
    cat <<EOF
Auto Proxy Installer - Tự động cài đặt proxy trên Linux

Usage:
    $0 [OPTIONS]

Options:
    --http <port> <username> <password>
        Cài đặt HTTP Proxy (non-interactive)
    
    --socks5 <port> <username> <password>
        Cài đặt SOCKS5 Proxy (non-interactive)
    
    --shadowsocks <port> <password> [method]
        Cài đặt Shadowsocks (non-interactive)
        Method mặc định: aes-256-gcm
    
    --uninstall [http|socks5|shadowsocks|all]
        Gỡ cài đặt proxy (mặc định: all)
    
    -h, --help
        Hiển thị hướng dẫn này

Examples:
    # Interactive mode
    sudo $0
    
    # Non-interactive HTTP proxy
    sudo $0 --http 8080 myuser mypassword123
    
    # Non-interactive SOCKS5 proxy
    sudo $0 --socks5 1080 myuser mypassword123
    
    # Non-interactive Shadowsocks
    sudo $0 --shadowsocks 8388 mypassword123 aes-256-gcm
    
    # Uninstall all
    sudo $0 --uninstall all

EOF
}

# Main function
main() {
    # Check root
    check_root
    
    # Initialize
    init_system
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Nhập số lựa chọn của bạn [1-5]: " choice
            # Trim whitespace
            choice=$(echo "$choice" | tr -d '[:space:]')
            
            case "$choice" in
                1)
                    install_http_interactive
                    read -p "Nhấn Enter để tiếp tục..."
                    ;;
                2)
                    install_socks5_interactive
                    read -p "Nhấn Enter để tiếp tục..."
                    ;;
                3)
                    install_shadowsocks_interactive
                    read -p "Nhấn Enter để tiếp tục..."
                    ;;
                4)
                    uninstall_interactive
                    read -p "Nhấn Enter để tiếp tục..."
                    ;;
                5)
                    info "Thoát chương trình"
                    exit 0
                    ;;
                *)
                    warn "Lựa chọn không hợp lệ: '$choice'. Vui lòng chọn từ 1-5."
                    sleep 2
                    ;;
            esac
        done
    else
        # Non-interactive mode
        case "$1" in
            --http)
                shift
                non_interactive_mode "http" "$@"
                ;;
            --socks5)
                shift
                non_interactive_mode "socks5" "$@"
                ;;
            --shadowsocks|--ss)
                shift
                non_interactive_mode "shadowsocks" "$@"
                ;;
            --uninstall)
                shift
                non_interactive_mode "uninstall" "${1:-all}"
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Tùy chọn không hợp lệ: $1"
                show_usage
                exit 1
                ;;
        esac
    fi
}

# Run main
main "$@"

