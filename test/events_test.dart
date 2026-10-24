import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mam/models/habit.dart';
import 'package:mam/models/inbox_item.dart';
import 'package:mam/models/reminder.dart';
import 'package:mam/services/notification_service.dart';
import 'package:mam/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late AppState s;

  Iterable<InboxItem> ofKind(InboxKind kind) => s.inbox.where((i) => i.kind == kind);

  setUp(() {
    now = DateTime(2026, 10, 24, 9);
    s = AppState(clock: () => now)..completeOnboarding(good: [], bad: []);
  });

  test('chào mừng khi hoàn tất giới thiệu', () {
    expect(s.inbox.single.title, 'Chào mừng bạn đến với Mầm!');
    expect(s.unreadCount, 1);
    s.markAllRead();
    expect(s.unreadCount, 0);
  });

  test('chuỗi 3 ngày được chúc mừng đúng một lần, kể cả khi bỏ chọn rồi chọn lại', () async {
    s.addGoodHabit('Chạy', '🏃');
    final h = s.goodHabits.single;
    h.doneDays.addAll({'2026-10-22', '2026-10-23'});
    final events = <InboxItem>[];
    s.events.listen(events.add);

    s.toggleToday(h);
    s.toggleToday(h);
    s.toggleToday(h);
    await pumpEventQueue();

    expect(ofKind(InboxKind.streak).single.title, '3 ngày liên tiếp!');
    expect(ofKind(InboxKind.daily).single.title, 'Đã tưới đủ cho Mầm hôm nay!');
    expect(events.where((e) => e.kind == InboxKind.streak), hasLength(1));
    expect(events.where((e) => e.kind == InboxKind.daily), hasLength(1));
  });

  test('chỉ báo cột mốc cao nhất, rồi bắt đầu lại sau khi tái phạm', () {
    s.addBadHabit('Trà sữa', '🧋', costPerDay: 40000);
    final b = s.badHabits.single;

    now = now.add(const Duration(days: 3, hours: 1));
    s.refreshEvents();
    s.refreshEvents();
    final clean = ofKind(InboxKind.clean).single;
    expect(clean.title, 'Cột mốc 3 ngày!');
    expect(clean.body, contains('tiết kiệm được'));

    s.relapse(b);
    expect(s.inbox.first.kind, InboxKind.relapse);
    expect(s.inbox.first.body, contains('3 ngày'));

    now = now.add(const Duration(days: 1, minutes: 1));
    s.refreshEvents();
    expect(s.inbox.first.title, 'Cột mốc 1 ngày!');
  });

  test('lên cấp được báo một lần', () {
    s.addGoodHabit('Nước', '💧');
    final h = s.goodHabits.single;
    h.doneDays.addAll({'2026-10-01', '2026-10-03'});
    s.toggleToday(h);
    expect(ofKind(InboxKind.level).single.title, 'Mầm lên cấp 2: Nảy mầm!');
    s.toggleToday(h);
    s.toggleToday(h);
    expect(ofKind(InboxKind.level), hasLength(1));
  });

  test('dữ liệu từ bản cũ không dội thông báo, nhưng thành tích mới vẫn được báo', () async {
    final old = GoodHabit(
      id: 'g',
      name: 'Chạy',
      emoji: '🏃',
      doneDays: {'2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23', '2026-10-24'},
    );
    SharedPreferences.setMockInitialValues({
      'mam_state_v1': jsonEncode({
        'onboarded': true,
        'good': [old.toJson()],
        'bad': [],
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final loaded = AppState(prefs: prefs, clock: () => now)..load();
    expect(loaded.inbox, isEmpty);
    expect(loaded.takeUndelivered(), isEmpty);

    now = DateTime(2026, 10, 26, 9);
    final h = loaded.goodHabits.single..doneDays.add('2026-10-25');
    loaded.toggleToday(h);
    expect(loaded.inbox.where((i) => i.kind == InboxKind.streak).single.title, '7 ngày liên tiếp!');
  });

  test('sự kiện phát sinh khi chưa có ai nghe được giữ lại cho màn hình chính', () {
    s.addBadHabit('Trà sữa', '🧋');
    now = now.add(const Duration(days: 1, hours: 1));
    s.refreshEvents();
    final pending = s.takeUndelivered();
    expect(pending.map((e) => e.title), contains('Cột mốc 1 ngày!'));
    expect(s.takeUndelivered(), isEmpty);
  });

  test('lưu và đọc lại nhắc nhở cùng hộp thông báo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = AppState(prefs: prefs, clock: () => now)
      ..completeOnboarding(
        good: [goodHabitTemplates[1]],
        bad: [badHabitTemplates.first],
        enableReminders: true,
      );
    a.updateReminders(
      (r) => r
        ..water = true
        ..waterEvery = 90,
    );
    a.setGoodReminder(a.goodHabits.single, HabitReminder(minutes: 7 * 60, weekdays: {1, 2}));

    final b = AppState(prefs: prefs, clock: () => now)..load();
    expect(b.reminders.enabled, isTrue);
    expect(b.reminders.water, isTrue);
    expect(b.reminders.waterEvery, 90);
    expect(b.goodHabits.single.reminder!.weekdays, {1, 2});
    expect(b.badHabits.single.reminder!.minutes, 14 * 60 + 30);
    expect(b.inbox.single.title, 'Chào mừng bạn đến với Mầm!');
  });

  test('đặt lại lịch nhắc mỗi khi cài đặt thay đổi', () async {
    final service = PreviewNotificationService();
    final state = AppState(clock: () => now, notifications: service)
      ..completeOnboarding(good: [], bad: [], enableReminders: true);
    await pumpEventQueue();
    expect(service.applied, hasLength(2));

    state.updateReminders((r) => r.water = true);
    await pumpEventQueue();
    expect(service.applied, hasLength(9));

    state.updateReminders((r) => r.enabled = false);
    await pumpEventQueue();
    expect(service.applied, isEmpty);
  });

  test('bật nhắc nhở ghi nhận quyền của hệ điều hành', () async {
    final service = PreviewNotificationService(granted: false);
    final state = AppState(clock: () => now, notifications: service)..completeOnboarding(good: [], bad: []);
    expect(await state.enableReminders(), isFalse);
    expect(state.reminders.enabled, isTrue);
    expect(state.notificationsAllowed, isFalse);

    service.granted = true;
    await state.refreshPermission();
    expect(state.notificationsAllowed, isTrue);
  });
}
