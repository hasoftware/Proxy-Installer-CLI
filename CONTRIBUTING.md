# Contributing to Auto Proxy Installer

Cảm ơn bạn đã quan tâm đến việc đóng góp cho Auto Proxy Installer! 🎉

## Cách đóng góp

### Báo cáo lỗi (Bug Reports)

Nếu bạn phát hiện lỗi, vui lòng:

1. Kiểm tra xem lỗi đã được báo cáo chưa trong [Issues](https://github.com/hasoftware/Proxy-Installer-CLI/issues)
2. Tạo issue mới với:
   - Mô tả chi tiết về lỗi
   - Các bước để reproduce lỗi
   - Thông tin hệ thống (OS, version, distro)
   - Log files nếu có (`/var/log/auto-proxy-installer.log`)

### Đề xuất tính năng (Feature Requests)

Chúng tôi luôn hoan nghênh các đề xuất cải thiện! Vui lòng:

1. Kiểm tra xem tính năng đã được đề xuất chưa
2. Tạo issue mới với:
   - Mô tả chi tiết về tính năng
   - Lý do tại sao tính năng này hữu ích
   - Ví dụ use case nếu có

### Đóng góp code (Pull Requests)

1. **Fork repository**

   ```bash
   git clone https://github.com/your-username/Proxy-Installer-CLI.git
   cd Proxy-Installer-CLI
   ```

2. **Tạo branch mới**

   ```bash
   git checkout -b feature/your-feature-name
   # hoặc
   git checkout -b fix/your-bug-fix
   ```

3. **Thực hiện thay đổi**

   - Tuân thủ coding style hiện tại
   - Thêm comments cho code phức tạp
   - Đảm bảo script vẫn chạy được trên các distro được hỗ trợ

4. **Test thay đổi**

   ```bash
   # Syntax check
   bash -n auto-proxy-installer.sh
   bash -n lib/*.sh
   bash -n modules/*.sh

   # Test trên máy thật (nếu có thể)
   sudo ./auto-proxy-installer.sh --help
   ```

5. **Commit changes**

   ```bash
   git add .
   git commit -m "feat: Add new feature description"
   # hoặc
   git commit -m "fix: Fix bug description"
   ```

6. **Push và tạo Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```

## Coding Guidelines

### Bash Style

- Sử dụng `set -euo pipefail` ở đầu script
- Sử dụng `local` cho biến trong functions
- Quote tất cả variables: `"$variable"`
- Sử dụng `[[ ]]` thay vì `[ ]` khi có thể
- Thêm comments cho logic phức tạp

### Code Structure

- Giữ functions nhỏ và focused
- Mỗi module trong `modules/` nên độc lập
- Sử dụng logging functions từ `lib/utils.sh`

### Naming Conventions

- Functions: `snake_case`
- Variables: `UPPER_CASE` cho global, `lower_case` cho local
- Files: `lowercase-with-dashes.sh`

## Testing

Trước khi submit PR, vui lòng:

1. ✅ Chạy syntax check: `bash -n script.sh`
2. ✅ Test trên ít nhất 1 distro được hỗ trợ
3. ✅ Đảm bảo không có lỗi shellcheck nghiêm trọng
4. ✅ Test cả interactive và non-interactive mode

## Commit Message Format

Sử dụng format:

```
type: Short description

Longer description if needed
```

Types:

- `feat`: Tính năng mới
- `fix`: Sửa lỗi
- `docs`: Cập nhật documentation
- `style`: Formatting, không ảnh hưởng code
- `refactor`: Refactor code
- `test`: Thêm tests
- `chore`: Cập nhật build/config

## Questions?

Nếu có câu hỏi, vui lòng:

- Tạo issue với label `question`
- Hoặc liên hệ maintainer

Cảm ơn bạn đã đóng góp! 🙏
