import 'package:flutter_test/flutter_test.dart';
import 'package:mam/models/habit.dart';
import 'package:mam/models/reminder.dart';
import 'package:mam/services/reminder_planner.dart';

void main() {
  // Thứ bảy.
  final now = DateTime(2026, 10, 24, 9);

  ReminderSettings settings({bool water = false, bool greetings = true}) => ReminderSettings()
    ..enabled = true
    ..water = water
    ..morning = greetings
    ..evening = greetings;

  test('tắt nhắc nhở thì không đặt lịch nào', () {
    expect(planNotifications(settings: ReminderSettings(), good: [], bad: [], now: now), isEmpty);
  });

  test('lời chào sáng/tối và nhắc uống nước hằng ngày', () {
    final plan = planNotifications(settings: settings(water: true), good: [], bad: [], now: now);
    // Sáng + tối + 7 lần uống nước (8h đến 20h, 2 giờ một lần).
    expect(plan, hasLength(9));
    expect(plan.every((p) => p.repeat == Repeat.daily), isTrue);
    expect(plan.where((p) => p.payload == 'water').map((p) => p.minutes), [
      480,
      600,
      720,
      840,
      960,
      1080,
      1200,
    ]);
    expect(plan.map((p) => p.id).toSet(), hasLength(plan.length));
  });

  test('nhắc theo vài thứ trong tuần thì đặt lịch hằng tuần', () {
    final h = GoodHabit(
      id: 'g',
      name: 'Chạy',
      emoji: '🏃',
      reminder: HabitReminder(minutes: 17 * 60 + 30, weekdays: {5, 1, 3}),
    );
    final plan = planNotifications(settings: settings(greetings: false), good: [h], bad: [], now: now);
    expect(plan.map((p) => (p.repeat, p.weekday, p.minutes)), [
      (Repeat.weekly, 1, 1050),
      (Repeat.weekly, 3, 1050),
      (Repeat.weekly, 5, 1050),
    ]);
    expect(plan.first.payload, 'habit:g');
    expect(plan.first.title, '🏃 Chạy');
  });

  test('nhắc đã tắt thì bỏ qua', () {
    final h = GoodHabit(
      id: 'g',
      name: 'Chạy',
      emoji: '🏃',
      reminder: HabitReminder(minutes: 600, enabled: false),
    );
    expect(planNotifications(settings: settings(greetings: false), good: [h], bad: [], now: now), isEmpty);
  });

  test('nhắc giờ hay thèm và cột mốc kế tiếp', () {
    final b = BadHabit(
      id: 'b',
      name: 'Trà sữa',
      emoji: '🧋',
      cleanSince: now.subtract(const Duration(days: 2, hours: 3)),
      reminder: HabitReminder(minutes: 14 * 60 + 30),
    );
    final plan = planNotifications(settings: settings(greetings: false), good: [], bad: [b], now: now);
    final craving = plan.firstWhere((p) => p.payload == 'craving:b');
    expect(craving.repeat, Repeat.daily);
    expect(craving.minutes, 870);
    final milestone = plan.firstWhere((p) => p.repeat == Repeat.once);
    expect(milestone.at, b.cleanSince.add(const Duration(days: 3)));
    expect(milestone.title, contains('3 ngày'));
    expect(milestone.channel, PlannedNotification.channelMilestones);
  });

  test('tắt báo cột mốc thì không đặt lịch cột mốc', () {
    final b = BadHabit(id: 'b', name: 'Trà sữa', emoji: '🧋', cleanSince: now);
    final plan = planNotifications(
      settings: settings(greetings: false)..milestones = false,
      good: [],
      bad: [b],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('không vượt quá giới hạn thông báo chờ của iOS', () {
    final r = settings(water: true)
      ..waterEvery = 30
      ..waterFrom = 0
      ..waterTo = 23 * 60 + 30;
    // 3 thói quen nhắc 5 ngày/tuần = 15 lịch hằng tuần, cộng 48 lần uống nước và 2 lời chào.
    final good = [
      for (var i = 0; i < 3; i++)
        GoodHabit(
          id: 'g$i',
          name: 'Thói quen $i',
          emoji: '⭐',
          reminder: HabitReminder(minutes: 600 + i, weekdays: {1, 2, 3, 4, 5}),
        ),
    ];
    final plan = planNotifications(settings: r, good: good, bad: [], now: now);
    expect(plan, hasLength(maxPlanned));
    // Lời chào và nhắc thói quen được ưu tiên giữ lại, nhắc uống nước bị cắt bớt.
    expect(plan.take(2).map((p) => p.payload), ['home', 'home']);
    expect(plan.where((p) => p.payload.startsWith('habit:')), hasLength(15));
    expect(plan.where((p) => p.payload == 'water'), hasLength(43));
  });

  test('đếm lời nhắc trong ngày và tìm lời nhắc kế tiếp', () {
    final h = GoodHabit(
      id: 'g',
      name: 'Chạy',
      emoji: '🏃',
      reminder: HabitReminder(minutes: 600, weekdays: {6}),
    );
    final plan = planNotifications(settings: settings(), good: [h], bad: [], now: now);
    expect(notificationsOn(plan, now), hasLength(3));
    expect(notificationsOn(plan, now.add(const Duration(days: 1))), hasLength(2));

    final next = nextNotification(plan, now)!;
    expect(next.at, DateTime(2026, 10, 24, 10));
    expect(describeNext(next, now), '10:00 · 🏃 Chạy');

    final night = DateTime(2026, 10, 24, 22);
    expect(describeNext(nextNotification(plan, night)!, night), 'Ngày mai 08:00 · ☀️ Chào buổi sáng!');
  });

  test('giờ uống nước theo khoảng và khung giờ', () {
    final r = ReminderSettings()
      ..waterEvery = 90
      ..waterFrom = 9 * 60
      ..waterTo = 13 * 60;
    expect(r.waterSlots, [540, 630, 720]);
    r.waterTo = 8 * 60;
    expect(r.waterSlots, isEmpty);
  });
}
