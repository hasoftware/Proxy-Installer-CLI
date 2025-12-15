# Auto Proxy Installer

Script tự động phát hiện distro Linux và cài đặt proxy theo lựa chọn của người dùng.

## Tính năng

- ✅ Tự động phát hiện hệ điều hành Linux (Ubuntu/Debian, CentOS/RHEL, AlmaLinux, Rocky, Amazon Linux)
- ✅ Hỗ trợ 3 loại proxy:
  - HTTP Proxy (Squid với basic auth)
  - SOCKS5 Proxy (Dante-server hoặc microsocks)
  - Shadowsocks (shadowsocks-libev hoặc shadowsocks-rust)
- ✅ Chế độ interactive và non-interactive
- ✅ Tự động mở firewall ports (ufw/firewalld)
- ✅ Tự động phát hiện IP công cộng
- ✅ Validate input đầy đủ
- ✅ Logging chi tiết
- ✅ Uninstall hoàn chỉnh

## Yêu cầu

- Hệ điều hành: Linux (Ubuntu/Debian, CentOS/RHEL, AlmaLinux, Rocky, Amazon Linux)
- Quyền: Root hoặc sudo
- Bash: POSIX-compatible bash

## Cài đặt

1. Clone hoặc tải repository:

```bash
git clone <repository-url>
cd ShadowRocket-Installer
```

2. Cấp quyền thực thi:

```bash
chmod +x auto-proxy-installer.sh
```

3. Chạy script:

```bash
sudo ./auto-proxy-installer.sh
```

## Sử dụng

### Chế độ Interactive (Mặc định)

Chạy script không có tham số để vào chế độ interactive:

```bash
sudo ./auto-proxy-installer.sh
```

Menu sẽ hiển thị:

1. Cài Proxy HTTP
2. Cài Proxy SOCKS5
3. Cài Shadowsocks (cho Shadowrocket)
4. Gỡ cài đặt
5. Thoát

### Chế độ Non-Interactive

#### Cài đặt HTTP Proxy

```bash
sudo ./auto-proxy-installer.sh --http <port> <username> <password>
```

Ví dụ:

```bash
sudo ./auto-proxy-installer.sh --http 8080 myuser mypassword123
```

#### Cài đặt SOCKS5 Proxy

```bash
sudo ./auto-proxy-installer.sh --socks5 <port> <username> <password>
```

Ví dụ:

```bash
sudo ./auto-proxy-installer.sh --socks5 1080 myuser mypassword123
```

#### Cài đặt Shadowsocks

```bash
sudo ./auto-proxy-installer.sh --shadowsocks <port> <password> [method]
```

Ví dụ:

```bash
sudo ./auto-proxy-installer.sh --shadowsocks 8388 mypassword123 aes-256-gcm
```

Methods hỗ trợ:

- `aes-256-gcm` (mặc định, khuyến nghị)
- `chacha20-ietf-poly1305`
- `aes-128-gcm`

#### Gỡ cài đặt

```bash
sudo ./auto-proxy-installer.sh --uninstall [http|socks5|shadowsocks|all]
```

Ví dụ:

```bash
# Gỡ tất cả
sudo ./auto-proxy-installer.sh --uninstall all

# Gỡ chỉ HTTP proxy
sudo ./auto-proxy-installer.sh --uninstall http
```

## Cấu trúc dự án

```
.
├── auto-proxy-installer.sh    # Script chính (entry point)
├── lib/
│   ├── utils.sh              # Utility functions (logging, validation, IP detection)
│   ├── os_detect.sh          # OS detection
│   ├── pkg.sh                # Package management
│   └── firewall.sh            # Firewall management
├── modules/
│   ├── http_squid.sh         # HTTP Proxy installation
│   ├── socks5.sh             # SOCKS5 Proxy installation
│   ├── shadowsocks.sh        # Shadowsocks installation
│   └── uninstall.sh          # Uninstall functions
└── README.md                 # Tài liệu này
```

## Chi tiết kỹ thuật

### HTTP Proxy (Squid)

- Package: `squid`
- Authentication: Basic Auth với htpasswd
- Config: `/etc/squid/squid.conf`
- Password file: `/etc/squid/passwords`
- Service: `squid`
- Log: `/var/log/squid/`

### SOCKS5 Proxy

**Dante-server** (ưu tiên nếu có sẵn):

- Package: `dante-server` (Debian/Ubuntu) hoặc `dante` (RHEL/CentOS)
- Config: `/etc/danted.conf`
- Service: `danted`

**microsocks** (fallback):

- Compile từ source nếu dante không có sẵn
- Binary: `/usr/local/bin/microsocks`
- Password file: `/etc/microsocks/passwd`
- Service: `microsocks`

### Shadowsocks

**shadowsocks-libev** (ưu tiên nếu có sẵn):

- Package: `shadowsocks-libev`
- Config: `/etc/shadowsocks-libev/config.json`
- Service: `shadowsocks-libev`

**shadowsocks-rust** (fallback):

- Download binary từ GitHub releases
- Binary: `/usr/local/bin/ss-server`
- Config: `/etc/shadowsocks-rust/config.json`
- Service: `shadowsocks-rust`

### Firewall

Script tự động phát hiện và cấu hình:

- **ufw**: Ubuntu/Debian
- **firewalld**: CentOS/RHEL/Fedora
- Nếu không có firewall tool, sẽ cảnh báo và tiếp tục

### State Management

Thông tin về các proxy đã cài được lưu tại:

- `/etc/auto-proxy-installer/installed_proxies.txt`

**Lưu ý**: Password không được lưu trong file state vì lý do bảo mật.

### Logging

- Console: Output với prefix [INFO], [WARN], [ERROR], [OK]
- File log: `/var/log/auto-proxy-installer.log`

## Sau khi cài đặt

Script sẽ hiển thị thông tin kết nối:

### HTTP Proxy

```
URL: http://username:password@IP:PORT
```

### SOCKS5 Proxy

```
URL: socks5://username:password@IP:PORT
```

### Shadowsocks

```
Server: IP
Port: PORT
Password: PASSWORD
Method: METHOD
SS URI: ss://...
```

## Kiểm tra và Test

### Kiểm tra service

```bash
# HTTP Proxy
systemctl status squid

# SOCKS5 Proxy (Dante)
systemctl status danted

# SOCKS5 Proxy (microsocks)
systemctl status microsocks

# Shadowsocks (libev)
systemctl status shadowsocks-libev

# Shadowsocks (rust)
systemctl status shadowsocks-rust
```

### Test Proxy

**HTTP Proxy:**

```bash
curl -x http://username:password@IP:PORT https://api.ipify.org
```

**SOCKS5 Proxy:**

```bash
curl --socks5 username:password@IP:PORT https://api.ipify.org
```

**Shadowsocks:**
Sử dụng client như Shadowrocket, V2Ray, hoặc shadowsocks client với thông tin đã cung cấp.

## Troubleshooting

### Lỗi "Port đang được sử dụng"

Kiểm tra port nào đang sử dụng:

```bash
ss -lntup | grep :PORT
# hoặc
netstat -lntup | grep :PORT
```

### Lỗi "Không thể phát hiện OS"

Script sẽ thử các phương pháp:

1. `/etc/os-release`
2. `lsb_release -a`
3. `uname -a`

Nếu vẫn lỗi, kiểm tra file `/etc/os-release` có tồn tại không.

### Lỗi khi cài package

Một số distro có thể không có sẵn package trong repository mặc định. Script sẽ tự động fallback sang phương án khác (ví dụ: compile từ source hoặc download binary).

### Service không khởi động

Kiểm tra log:

```bash
journalctl -u SERVICE_NAME -n 50
```

Ví dụ:

```bash
journalctl -u squid -n 50
journalctl -u shadowsocks-libev -n 50
```

## Bảo mật

- ✅ Script chỉ lắng nghe trên `0.0.0.0` nhưng yêu cầu authentication
- ✅ Password không được lưu trong log file
- ✅ Password được mask khi hiển thị
- ✅ Config files có quyền 600 (chỉ root đọc được)
- ✅ Deny anonymous connections

## Hỗ trợ

Nếu gặp vấn đề, vui lòng:

1. Kiểm tra log: `/var/log/auto-proxy-installer.log`
2. Kiểm tra service logs: `journalctl -u SERVICE_NAME`
3. Đảm bảo đã chạy với quyền root: `sudo ./auto-proxy-installer.sh`

## License

MIT License

## Tác giả

Auto Proxy Installer - Script tự động cài đặt proxy cho Linux
