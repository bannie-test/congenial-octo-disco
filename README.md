# Mầm 🌱: xây thói quen tốt, bỏ thói quen xấu

Ứng dụng Flutter (Android + iOS) xoay quanh một mầm cây có cảm xúc:

- **Chăm thói quen tốt**: mầm lớn dần qua 6 cấp (Hạt giống → Ra hoa).
- **Cai thói quen xấu**: mỗi ngày "sạch" mầm khỏe hơn và bạn tiết kiệm được tiền. Tái phạm thì mầm héo, mặt mếu.

| Onboarding | Màn hình chính | Đang cai | Mầm héo |
|---|---|---|---|
| ![](docs/screenshots/onboarding.png) | ![](docs/screenshots/home.png) | ![](docs/screenshots/quitting.png) | ![](docs/screenshots/wilted.png) |

## Tính năng MVP

- Onboarding 3 bước, chọn thói quen từ danh sách gợi ý gần gũi với người Việt (trà sữa, TikTok…).
- Chạm 1 lần để hoàn thành thói quen, có streak 🔥, rung phản hồi (haptic) và animation.
- Bộ đếm thời gian "sạch" chạy theo từng giây, kèm số tiền đã tiết kiệm.
- Nút **"Tôi đang thèm"** mở bài thở 60 giây (hít 4s, giữ 4s, thở ra 6s).
- Ghi nhận tái phạm với lời lẽ không phán xét, rồi bộ đếm bắt đầu lại.
- Mầm cây vẽ bằng `CustomPainter`: lắc lư, chớp mắt, lớn và héo mượt theo dữ liệu.
- Lưu dữ liệu trên máy (`shared_preferences`), hỗ trợ dark mode.
- Thêm thói quen bằng nút `+`. Nhấn giữ một thói quen để xóa.

## Cấu trúc

```
lib/
  main.dart                  # Khởi tạo app, AppScope (InheritedNotifier)
  theme.dart                 # Theme Material 3, formatVnd
  models/habit.dart          # GoodHabit, BadHabit, danh sách gợi ý
  state/app_state.dart       # Logic: điểm tăng trưởng, cấp độ, sức sống, lưu trữ
  widgets/sprout.dart        # Mầm cây vẽ tay + animation
  screens/
    onboarding_screen.dart
    home_screen.dart
    craving_screen.dart      # Bài thở vượt cơn thèm
    add_habit_sheet.dart
test/                        # Unit test logic + widget test luồng onboarding
```

## Chạy dự án

```bash
flutter pub get
flutter run          # chọn máy ảo Android / iOS simulator
flutter test
flutter analyze
```

## Lộ trình tiếp theo

1. Thông báo nhắc nhở (`flutter_local_notifications`).
2. Widget màn hình chính (WidgetKit / Glance) để đánh dấu thói quen không cần mở app.
3. Paywall thuê bao qua RevenueCat: theme và nhân vật mới, thống kê nâng cao.
4. Màn thống kê (lịch nhiệt, biểu đồ tiền tiết kiệm).
5. Đồng bộ Apple Health / Health Connect.
6. Nhân vật Rive với nhiều biểu cảm hơn, âm thanh nhẹ khi hoàn thành.
