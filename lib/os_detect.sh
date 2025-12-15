#!/bin/bash
# OS detection functions

detect_os() {
    local os_id=""
    local os_version=""
    local os_codename=""
    
    # Try /etc/os-release first
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_id="${ID:-}"
        os_version="${VERSION_ID:-}"
        os_codename="${VERSION_CODENAME:-}"
        
        # Handle ID_LIKE for better compatibility
        if [ -z "$os_id" ] && [ -n "${ID_LIKE:-}" ]; then
            os_id="${ID_LIKE%% *}"
        fi
        
        # Normalize os_id
        case "${os_id,,}" in
            ubuntu)
                os_id="ubuntu"
                ;;
            debian)
                os_id="debian"
                ;;
            centos|rhel|rocky|almalinux|oracle)
                os_id="rhel"
                ;;
            fedora)
                os_id="fedora"
                ;;
            amazon)
                os_id="amazon"
                ;;
            *)
                os_id="${os_id,,}"
                ;;
        esac
    fi
    
    # Fallback to lsb_release if available
    if [ -z "$os_id" ] && command -v lsb_release >/dev/null 2>&1; then
        os_id=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
        os_version=$(lsb_release -sr 2>/dev/null || true)
        os_codename=$(lsb_release -sc 2>/dev/null || true)
    fi
    
    # Final fallback to uname
    if [ -z "$os_id" ]; then
        local kernel=$(uname -a 2>/dev/null || true)
        case "$kernel" in
            *[Uu]buntu*)
                os_id="ubuntu"
                ;;
            *[Dd]ebian*)
                os_id="debian"
                ;;
            *[Cc]ent[Oo][Ss]*|*[Rr][Hh][Ee][Ll]*)
                os_id="rhel"
                ;;
            *[Ff]edora*)
                os_id="fedora"
                ;;
            *)
                os_id="unknown"
                ;;
        esac
    fi
    
    # Normalize Amazon Linux
    if [ -f /etc/system-release ]; then
        if grep -qi "amazon linux" /etc/system-release; then
            os_id="amazon"
        fi
    fi
    
    echo "$os_id"
}

detect_package_manager() {
    local os_id="$1"
    
    case "$os_id" in
        ubuntu|debian)
            if command -v apt >/dev/null 2>&1; then
                echo "apt"
            elif command -v apt-get >/dev/null 2>&1; then
                echo "apt-get"
            else
                echo "unknown"
            fi
            ;;
        rhel|centos|rocky|almalinux|oracle|amazon)
            if command -v dnf >/dev/null 2>&1; then
                echo "dnf"
            elif command -v yum >/dev/null 2>&1; then
                echo "yum"
            else
                echo "unknown"
            fi
            ;;
        fedora)
            if command -v dnf >/dev/null 2>&1; then
                echo "dnf"
            else
                echo "unknown"
            fi
            ;;
        *)
            # Try to detect by checking available commands
            if command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
                echo "apt"
            elif command -v dnf >/dev/null 2>&1; then
                echo "dnf"
            elif command -v yum >/dev/null 2>&1; then
                echo "yum"
            else
                echo "unknown"
            fi
            ;;
    esac
}

get_os_info() {
    local os_id=$(detect_os)
    local pkg_manager=$(detect_package_manager "$os_id")
    
    echo "OS_ID=$os_id"
    echo "PKG_MANAGER=$pkg_manager"
}

