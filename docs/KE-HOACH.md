# Kế hoạch: Lumi (bản clone kỹ thuật kiểu Litmatch)

## 1. Mục tiêu
- App ghép đôi ẩn danh: gặp người lạ, chat 3 phút, cùng thích thì thành bạn bè.
- Tên, logo, giao diện tự thiết kế (tông tối, gradient, animation mượt). Không dùng tài sản của Litmatch.
- Chất lượng tech test: kiến trúc sạch, có test, có tài liệu, có APK/IPA.

## 2. Kiến trúc
- **Mobile:** Flutter, Riverpod, go_router, Dio, Socket.IO, LiveKit. Tổ chức clean architecture theo feature (domain/data/application/presentation). Hỗ trợ tiếng Việt (mặc định) và tiếng Anh.
- **Backend:** NestJS + TypeScript.
  - PostgreSQL (Prisma) cho dữ liệu; Redis cho hàng đợi ghép, presence, lock.
  - Socket.IO cho realtime.
  - JWT access/refresh, argon2, rate‑limit, Swagger.
- **Hạ tầng:** docker‑compose (postgres, redis, livekit, api); GitHub Actions build APK và IPA unsigned.

## 3. Tính năng theo giai đoạn
| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| 1. Nền tảng | Đăng ký/đăng nhập email, mã 6 số, quên mật khẩu; onboarding (18+) | Xong |
| 2. Soul Match | Hàng đợi, chat ẩn danh có đếm ngược, thích/bỏ qua, ghép bạn | Xong |
| 3. Bạn bè & chat | Chat 1‑1 realtime, đang gõ, đã xem, lịch sử, online | Xong |
| 4. An toàn | Báo cáo, chặn, cài đặt, đăng xuất, xoá tài khoản | Xong |
| 5. Mở rộng | Bảng tin + thả tim; Voice Match (LiveKit); push FCM | Bảng tin xong; Voice cần LiveKit server; FCM là stub |

## 4. Timeline (ước tính)
| Ngày | Việc |
|---|---|
| 1 | Thiết kế, schema DB, auth backend |
| 2 | Matching và realtime backend, test e2e |
| 3–4 | App Flutter: auth, onboarding, match, chat |
| 5 | Feed, voice, báo cáo/chặn, đa ngôn ngữ, polish UI |
| 6 | CI iOS/Android, build APK, tài liệu |

## 5. Cách chạy
```bash
docker compose up -d --build                  # API tại http://localhost:3000/docs
cd backend && npm test                        # test backend
cd mobile && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```
Ở dev, mã xác thực in ra console của API. Chi tiết xem README.md.
