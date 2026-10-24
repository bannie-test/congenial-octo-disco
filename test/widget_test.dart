import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mam/main.dart';
import 'package:mam/models/habit.dart';
import 'package:mam/services/notification_service.dart';
import 'package:mam/state/app_state.dart';

// Màn hình có animation lặp vô hạn (mầm lắc lư, sóng nước) nên không dùng pumpAndSettle.
Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Kích thước iPhone 15 để kiểm tra bố cục như trên máy thật.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Cuộn tới [finder] (kể cả mục chưa được dựng trong danh sách) và đặt nó
/// giữa màn hình để không bị thanh tiêu đề che.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

AppState onboardedState(PreviewNotificationService service) =>
    AppState(clock: () => DateTime(2026, 10, 24, 9), notifications: service)..completeOnboarding(
      good: [goodHabitTemplates[0], goodHabitTemplates[1]],
      bad: [badHabitTemplates[0]],
      enableReminders: true,
    );

void main() {
  testWidgets('onboarding 4 bước, bật nhắc nhở rồi tưới Mầm', (tester) async {
    usePhone(tester);
    final service = PreviewNotificationService();
    final state = AppState(clock: () => DateTime(2026, 10, 24, 9), notifications: service);
    await tester.pumpWidget(MamApp(state: state));

    expect(find.text('Chào bạn, mình là Mầm 🌱'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu'));
    await settle(tester);

    await tester.tap(find.textContaining('Uống đủ 2 lít nước'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await settle(tester);

    await tester.tap(find.textContaining('Trà sữa'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await settle(tester);

    expect(find.text('Để Mầm nhắc bạn nhé'), findsOneWidget);
    await tester.tap(find.text('Bật nhắc nhở 🔔'));
    await settle(tester);

    expect(state.onboarded, isTrue);
    expect(state.reminders.enabled, isTrue);
    // Đã chọn thói quen uống nước nên nhắc uống nước bật sẵn.
    expect(state.reminders.water, isTrue);
    expect(service.applied, isNotEmpty);
    expect(find.text('Mầm của bạn'), findsOneWidget);
    expect(find.text('Tưới Mầm hôm nay'), findsOneWidget);

    await reveal(tester, find.text('Uống đủ 2 lít nước'));
    await tester.tap(find.text('Uống đủ 2 lít nước'));
    await settle(tester, 15);
    expect(state.doneTodayCount, 1);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    // Hoàn thành đủ thói quen: banner chúc mừng trượt xuống.
    expect(find.text('Đã tưới đủ cho Mầm hôm nay!'), findsOneWidget);
    expect(state.unreadCount, 2);
  });

  testWidgets('màn nhắc nhở: bật và chỉnh nhắc uống nước', (tester) async {
    usePhone(tester);
    final state = onboardedState(PreviewNotificationService())..updateReminders((r) => r.water = false);
    await tester.pumpWidget(MamApp(state: state));
    await settle(tester);

    await tester.tap(find.byTooltip('Nhắc nhở'));
    await settle(tester);
    expect(find.text('Chào buổi sáng'), findsOneWidget);
    expect(find.text('Hôm nay Mầm nhắc bạn 4 lần'), findsOneWidget);

    await reveal(tester, find.text('Nhắc uống nước'));
    await tester.tap(find.text('Nhắc uống nước'));
    await settle(tester);
    expect(state.reminders.water, isTrue);
    // Thẻ đầu đã cuộn khỏi màn hình nên tìm cả phần tử ngoài màn hình.
    expect(find.text('Hôm nay Mầm nhắc bạn 11 lần', skipOffstage: false), findsOneWidget);

    await reveal(tester, find.text('1 giờ'));
    await tester.tap(find.text('1 giờ'));
    await settle(tester);
    expect(state.reminders.waterEvery, 60);
    expect(find.text('13 lần mỗi ngày · 1 giờ một lần'), findsOneWidget);
  });

  testWidgets('màn thông báo: xem và đánh dấu đã đọc', (tester) async {
    usePhone(tester);
    final state = onboardedState(PreviewNotificationService());
    await tester.pumpWidget(MamApp(state: state));
    await settle(tester);

    expect(state.unreadCount, 1);
    await tester.tap(find.byTooltip('Thông báo'));
    await settle(tester);
    expect(find.text('Chào mừng bạn đến với Mầm!'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);

    await tester.tap(find.text('Đọc hết'));
    await settle(tester);
    expect(state.unreadCount, 0);
  });

  testWidgets('bài thở khi thèm đếm ngược 60 giây', (tester) async {
    usePhone(tester);
    final state = onboardedState(PreviewNotificationService());
    await tester.pumpWidget(MamApp(state: state));
    await settle(tester);

    await reveal(tester, find.text('Tôi đang thèm'));
    await tester.tap(find.text('Tôi đang thèm'));
    await settle(tester);
    expect(find.textContaining(RegExp(r'Còn \d+ giây')), findsOneWidget);

    for (var i = 0; i < 62; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Bạn đã vượt qua cơn thèm 💪'), findsOneWidget);
    await tester.tap(find.text('Mình ổn rồi'));
    await settle(tester);
    expect(find.text('Mầm của bạn'), findsOneWidget);
  });
}
