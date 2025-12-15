#!/bin/bash
# Package management functions

# Source utils for logging
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIB_DIR/utils.sh"

install_packages() {
    local pkg_manager="$1"
    shift
    local packages=("$@")
    
    if [ ${#packages[@]} -eq 0 ]; then
        warn "Không có package nào để cài đặt"
        return 1
    fi
    
    info "Đang cài đặt packages: ${packages[*]}"
    
    case "$pkg_manager" in
        apt|apt-get)
            export DEBIAN_FRONTEND=noninteractive
            if [ "$pkg_manager" = "apt" ]; then
                apt update -qq
                apt install -y -qq "${packages[@]}"
            else
                apt-get update -qq
                apt-get install -y -qq "${packages[@]}"
            fi
            ;;
        yum)
            yum install -y -q "${packages[@]}"
            ;;
        dnf)
            dnf install -y -q "${packages[@]}"
            ;;
        *)
            error "Package manager không được hỗ trợ: $pkg_manager"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        ok "Đã cài đặt packages thành công"
        return 0
    else
        error "Lỗi khi cài đặt packages"
        return 1
    fi
}

check_package_available() {
    local pkg_manager="$1"
    local package="$2"
    
    case "$pkg_manager" in
        apt|apt-get)
            if apt-cache show "$package" >/dev/null 2>&1; then
                return 0
            fi
            ;;
        yum)
            if yum info "$package" >/dev/null 2>&1; then
                return 0
            fi
            ;;
        dnf)
            if dnf info "$package" >/dev/null 2>&1; then
                return 0
            fi
            ;;
    esac
    return 1
}

get_package_name() {
    local pkg_manager="$1"
    local package="$2"
    
    case "$pkg_manager" in
        apt|apt-get)
            # For apt, package name is usually the same
            echo "$package"
            ;;
        yum|dnf)
            # Map common package names
            case "$package" in
                apache2-utils)
                    echo "httpd-tools"
                    ;;
                *)
                    echo "$package"
                    ;;
            esac
            ;;
        *)
            echo "$package"
            ;;
    esac
}

