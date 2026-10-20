<div align="center">

# 💜 Lumi

**Kết nối bằng tâm hồn trước, ngoại hình sau.**

Ứng dụng hẹn hò & kết bạn với Soul Match, Voice Match, chat mã hoá trên thiết bị và mini game cho các cặp đôi.

[**⬇️ Tải ứng dụng**](https://github.com/gooduselabs/lumi-download/releases)

</div>

---

## ✨ Tính năng

- 🔮 **Soul Match** — ghép đôi theo tính cách & sở thích, trò chuyện ẩn danh trước khi lộ diện.
- 🎙️ **Voice Match** — làm quen qua giọng nói, gọi thoại/video với bạn bè (LiveKit).
- 🎯 **Bộ lọc độ tuổi & Gần đây** — tìm người phù hợp quanh bạn (vị trí được làm mờ để bảo vệ riêng tư).
- 🖼️ **Chat đa phương tiện** — gửi ảnh, tin nhắn thoại, tệp tin.
- 🔐 **Tin nhắn mã hoá trên thiết bị** — lịch sử lưu cục bộ bằng SQLCipher; server xoá tin sau khi đã giao.
- 🎮 **Mini game cặp đôi** — Thật hay Thách · Ai hiểu ai hơn · Cờ Caro · Vẽ & Đoán.

## 📸 Ảnh chụp màn hình

| Khám phá & ghép đôi | Bộ lọc, chat & gọi | Mini game |
|:---:|:---:|:---:|
| ![v1](docs/screenshots/v1-collage.png) | ![v2](docs/screenshots/v2-collage.png) | ![v3](docs/screenshots/v3-collage.png) |

## 🛠️ Công nghệ

| Thành phần | Công nghệ |
|---|---|
| Mobile | Flutter |
| Backend | NestJS · Prisma · PostgreSQL · Redis |
| Realtime | Socket.IO |
| Gọi thoại/video | LiveKit |

## 🚀 Chạy thử (dev)

```bash
docker compose up -d          # Postgres, Redis, LiveKit (dev keys)
cd backend && cp .env.example .env && npm i && npx prisma migrate dev && npm run start:dev
cd ../mobile && flutter run
```

## 📥 Tải về

Bản APK mới nhất: **https://github.com/gooduselabs/lumi-download/releases**
