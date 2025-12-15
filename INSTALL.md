# Hướng dẫn cài đặt nhanh

## Bước 1: Tải script

```bash
# Clone repository hoặc tải file
git clone <repository-url>
cd ShadowRocket-Installer
```

## Bước 2: Cấp quyền thực thi

Trên Linux:

```bash
chmod +x auto-proxy-installer.sh
chmod +x lib/*.sh
chmod +x modules/*.sh
```

## Bước 3: Chạy script

### Chế độ Interactive (Khuyến nghị cho người mới)

```bash
sudo ./auto-proxy-installer.sh
```

Sau đó làm theo hướng dẫn trên màn hình.

### Chế độ Non-Interactive (Cho automation)

**Cài HTTP Proxy:**

```bash
sudo ./auto-proxy-installer.sh --http 8080 username password123
```

**Cài SOCKS5 Proxy:**

```bash
sudo ./auto-proxy-installer.sh --socks5 1080 username password123
```

**Cài Shadowsocks:**

```bash
sudo ./auto-proxy-installer.sh --shadowsocks 8388 password123 aes-256-gcm
```

## Kiểm tra sau khi cài

```bash
# Kiểm tra service
systemctl status squid          # HTTP Proxy
systemctl status danted          # SOCKS5 (Dante)
systemctl status microsocks      # SOCKS5 (microsocks)
systemctl status shadowsocks-libev  # Shadowsocks (libev)
systemctl status shadowsocks-rust   # Shadowsocks (rust)

# Xem log
tail -f /var/log/auto-proxy-installer.log
```

## Gỡ cài đặt

```bash
sudo ./auto-proxy-installer.sh --uninstall all
```

## Lưu ý quan trọng

1. **Phải chạy với quyền root**: Script cần quyền root để cài đặt packages và cấu hình systemd services.

2. **Firewall**: Script sẽ tự động mở ports trên ufw hoặc firewalld. Nếu bạn dùng firewall khác, cần mở port thủ công.

3. **IP công cộng**: Script sẽ tự động phát hiện IP công cộng. Nếu không được, bạn sẽ được yêu cầu nhập thủ công.

4. **Port**: Đảm bảo port bạn chọn không bị trùng với port đang sử dụng. Script sẽ kiểm tra và cảnh báo nếu port đã được sử dụng.

5. **Password**: Không lưu password trong log files vì lý do bảo mật. Hãy lưu lại thông tin kết nối sau khi cài đặt.

## Troubleshooting

Nếu gặp lỗi, kiểm tra:

- Log file: `/var/log/auto-proxy-installer.log`
- Service logs: `journalctl -u SERVICE_NAME -n 50`
- Đảm bảo đã chạy với sudo: `sudo ./auto-proxy-installer.sh`
