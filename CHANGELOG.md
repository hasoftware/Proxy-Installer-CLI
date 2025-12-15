# Changelog

Tất cả các thay đổi đáng chú ý trong dự án này sẽ được ghi lại trong file này.

Format dựa trên [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
và dự án này tuân thủ [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial release
- Auto OS detection (Ubuntu/Debian, CentOS/RHEL, AlmaLinux, Rocky, Amazon Linux)
- HTTP Proxy installation với Squid
- SOCKS5 Proxy installation với Dante-server hoặc microsocks
- Shadowsocks installation với shadowsocks-libev hoặc shadowsocks-rust
- Interactive và non-interactive modes
- Automatic firewall port management (ufw/firewalld)
- Automatic public IP detection
- Comprehensive input validation
- Detailed logging system
- Complete uninstall functionality
- GitHub Actions workflow for testing
- MIT License
- Comprehensive documentation (README, INSTALL, CONTRIBUTING)

### Security

- Password không được lưu trong log files
- Password được mask khi hiển thị
- Config files có quyền 600 (chỉ root đọc được)
- Deny anonymous connections

## [1.0.0] - 2025-01-XX

### Added

- Initial release của Auto Proxy Installer
