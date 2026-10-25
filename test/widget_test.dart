import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mam/main.dart';
import 'package:mam/models/habit.dart';
import 'package:mam/models/reminder.dart';
import 'package:mam/screens/shell.dart';
import 'package:mam/services/notification_service.dart';
import 'package:mam/services/sound_service.dart';
import 'package:mam/state/app_state.dart';
import 'package:mam/widgets/habit_icon.dart';
import 'package:mam/widgets/sprout.dart';

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

AppState onboardedState({SoundService? sounds}) => AppState(
  clock: () => DateTime(2026, 10, 24, 9),
  notifications: PreviewNotificationService(),
  sounds: sounds,
)..completeOnboarding(good: [goodHabitTemplates[1]], bad: [badHabitTemplates[0]], enableReminders: true);

void main() {
  // Máy test không có gia tốc kế.
  setUpAll(() => TiltSensor.source = () => const Stream.empty());
  // Tab đang mở là biến toàn cục, cần đặt lại giữa các test.
  setUp(() => shellTab.value = ShellTabs.home);

  testWidgets('onboarding 4 bước, bật nhắc nhở rồi tưới Mầm đến khi đạt mục tiêu', (tester) async {
    usePhone(tester);
    final service = PreviewNotificationService();
    final sounds = SilentSoundService();
    final state = AppState(clock: () => DateTime(2026, 10, 24, 9), notifications: service, sounds: sounds);
    await tester.pumpWidget(MamApp(state: state));

    expect(find.text('Chào bạn, mình là Mầm 🌱'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu'));
    await settle(tester);

    // Uống nước đã được chọn sẵn và không bỏ được.
    expect(find.textContaining('mặc định'), findsOneWidget);
    await tester.tap(find.textContaining('Uống đủ 2 lít nước'));
    await tester.tap(find.textContaining('Chạy bộ 20 phút'));
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
    expect(state.goodHabits.map((h) => h.emoji), ['💧', '🏃']);
    expect(state.goodHabits.first.reminder!.mode, ReminderMode.interval);
    expect(state.goal, 2);
    expect(service.applied, isNotEmpty);
    expect(find.text('Tưới Mầm hôm nay'), findsOneWidget);

    await reveal(tester, find.text('Uống đủ 2 lít nước'));
    // Icon động: cốc nước cho uống nước, người chạy cho chạy bộ.
    expect(find.byType(WaterGlassIcon), findsOneWidget);
    expect(find.byType(StickFigureIcon), findsOneWidget);
    await tester.tap(find.text('Uống đủ 2 lít nước'));
    await settle(tester, 15);
    expect(state.doneTodayCount, 1);
    expect(find.text('Đạt mục tiêu hôm nay!'), findsNothing);

    await reveal(tester, find.text('Chạy bộ 20 phút'));
    await tester.tap(find.text('Chạy bộ 20 phút'));
    await settle(tester, 15);
    expect(find.text('Đạt mục tiêu hôm nay!'), findsOneWidget);
    expect(sounds.played, containsAllInOrder([Sfx.drop, Sfx.drop, Sfx.success]));
  });

  testWidgets('màn nhắc nhở: đổi chu kỳ nhắc uống nước', (tester) async {
    usePhone(tester);
    final state = onboardedState();
    await tester.pumpWidget(MamApp(state: state));
    await settle(tester);

    await tester.tap(find.byTooltip('Nhắc nhở'));
    await settle(tester);
    // Sáng, tối, 7 lần uống nước, chạy bộ, giờ hay thèm trà sữa.
    expect(find.text('Hôm nay Mầm nhắc bạn 11 lần'), findsOneWidget);

    await reveal(tester, find.text('Uống đủ 2 lít nước'));
    await tester.tap(find.text('Uống đủ 2 lít nước'));
    await settle(tester);
    expect(find.text('Lặp lại'), findsOneWidget);
    await tester.tap(find.text('Tuỳ chỉnh'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '1');
    await tester.enterText(find.byType(TextField).last, '30');
    await tester.pump();
    expect(find.text('9 lần mỗi ngày'), findsOneWidget);
    await reveal(tester, find.text('Lưu nhắc lặp lại'));
    await tester.tap(find.text('Lưu nhắc lặp lại'));
    await settle(tester);

    final water = state.goodHabits.first.reminder!;
    expect(water.every, 90);
    expect(water.slots, hasLength(9));
  });

  testWidgets('màn thông báo: xem và đánh dấu đã đọc', (tester) async {
    usePhone(tester);
    final state = onboardedState();
    await tester.pumpWidget(MamApp(state: state));
    await settle(tester);

    expect(state.unreadCount, 1);
    await tester.tap(find.byTooltip('Thông báo'));
    await settle(tester);
    expect(find.text('Chào mừng bạn đến với Mầm!'), findsOneWidget);

    await tester.tap(find.text('Đọc hết'));
    await settle(tester);
    expect(state.unreadCount, 0);
  });

  testWidgets('chạm vào Mầm: lời chào và đặt mục tiêu', (tester) async {
    usePhone(tester);
    final state = onboardedState();
    await tester.pumpWidget(MamApp(state: state));
    await settle(tester);

    await tester.tap(find.byType(SproutView).first);
    await settle(tester);
    expect(find.text('🎯 Mục tiêu mỗi ngày'), findsOneWidget);
    expect(find.text('Đang cập nhật thời tiết…'), findsOneWidget);
    expect(find.text('Chào buổi sáng! Mình vừa thức dậy cùng ánh nắng ☀️'), findsOneWidget);

    await tester.tap(find.byTooltip('Giảm mục tiêu'));
    await tester.pump();
    expect(state.goal, 1);
    await tester.tap(find.byType(SproutView).last);
    await settle(tester, 5);
    expect(find.text('Chào buổi sáng! Mình vừa thức dậy cùng ánh nắng ☀️'), findsNothing);
  });

  testWidgets('lịch, cảm xúc và thống kê', (tester) async {
    usePhone(tester);
    final state = onboardedState();
    await tester.pumpWidget(MamApp(state: state));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await settle(tester);
    await tester.tap(find.text('Thêm lịch'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Đi bộ công viên');
    await tester.tap(find.text('Lưu lịch'));
    await settle(tester);
    expect(state.events.single.weekday, DateTime.saturday);
    expect(find.text('Đi bộ công viên'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mood_outlined));
    await settle(tester);
    await tester.tap(find.text('Vui vẻ'));
    await tester.enterText(find.byType(TextField), 'Chạy bộ xong thấy khoẻ');
    await tester.tap(find.text('Lưu cảm xúc'));
    await settle(tester);
    expect(state.moodOn(state.now)!.mood.label, 'Vui vẻ');

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await settle(tester);
    expect(find.text('Mỗi ngày'), findsOneWidget);
    expect(find.text('Ngày đạt mục tiêu'), findsOneWidget);
    await tester.tap(find.text('30 ngày'));
    await settle(tester);
    expect(find.text('0/30'), findsOneWidget);
  });

  testWidgets('bài thở khi thèm đếm ngược 60 giây', (tester) async {
    usePhone(tester);
    final state = onboardedState();
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
    expect(find.text('Tôi đang thèm'), findsOneWidget);
  });
}
