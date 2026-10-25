import 'package:flutter_test/flutter_test.dart';
import 'package:mam/models/habit.dart';
import 'package:mam/models/journal.dart';
import 'package:mam/models/reminder.dart';
import 'package:mam/services/reminder_planner.dart';

void main() {
  // Thứ bảy.
  final now = DateTime(2026, 10, 24, 9);

  ReminderSettings settings({bool greetings = true}) => ReminderSettings()
    ..enabled = true
    ..morning = greetings
    ..evening = greetings;

  GoodHabit water([HabitReminder? r]) =>
      GoodHabit(id: 'w', name: 'Uống đủ 2 lít nước', emoji: '💧', reminder: r ?? HabitReminder.interval());

  test('tắt nhắc nhở thì không đặt lịch nào', () {
    expect(planNotifications(settings: ReminderSettings(), good: [water()], bad: [], now: now), isEmpty);
  });

  test('uống nước là thói quen nhắc lặp lại theo chu kỳ', () {
    final plan = planNotifications(settings: settings(), good: [water()], bad: [], now: now);
    // Sáng + tối + 7 lần uống nước (8h đến 20h, 2 giờ một lần).
    expect(plan, hasLength(9));
    expect(plan.every((p) => p.repeat == Repeat.daily), isTrue);
    final drinks = plan.where((p) => p.payload == 'habit:w');
    expect(drinks.map((p) => p.minutes), [480, 600, 720, 840, 960, 1080, 1200]);
    expect(drinks.first.title, '💧 Uống nước thôi!');
    expect(plan.map((p) => p.id).toSet(), hasLength(plan.length));
  });

  test('chu kỳ tuỳ chỉnh và khung giờ', () {
    final r = HabitReminder.interval(every: 75, from: 9 * 60, to: 12 * 60);
    expect(r.slots, [540, 615, 690]);
    expect(r.timeLabel, 'Mỗi 1 giờ 15 phút, 09:00–12:00');
    expect(HabitReminder.interval(every: 2).slots, isEmpty, reason: 'chu kỳ quá ngắn');
    expect(HabitReminder.interval(from: 600, to: 500).slots, isEmpty);
  });

  test('nhắc theo vài thứ trong tuần thì đặt lịch hằng tuần', () {
    final h = GoodHabit(
      id: 'g',
      name: 'Chạy bộ',
      emoji: '🏃',
      reminder: HabitReminder(minutes: 17 * 60 + 30, weekdays: {5, 1, 3}),
    );
    final plan = planNotifications(settings: settings(greetings: false), good: [h], bad: [], now: now);
    expect(plan.map((p) => (p.repeat, p.weekday, p.minutes)), [
      (Repeat.weekly, 1, 1050),
      (Repeat.weekly, 3, 1050),
      (Repeat.weekly, 5, 1050),
    ]);
    expect(plan.first.title, '🏃 Chạy bộ');
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

  test('lịch tập: hằng tuần và một lần (bỏ qua nếu đã qua)', () {
    final gym = GoodHabit(id: 'gym', name: 'Tập thể dục', emoji: '🏋️');
    final events = [
      PlanEvent(id: '1', title: 'Đi bộ', emoji: '🚶', minutes: 18 * 60, habitId: 'gym', weekday: 1),
      PlanEvent(id: '2', title: 'Bơi', emoji: '🏊', minutes: 19 * 60, date: DateTime(2026, 10, 24)),
      PlanEvent(id: '3', title: 'Cũ', emoji: '🎯', minutes: 7 * 60, date: DateTime(2026, 10, 24)),
      PlanEvent(id: '4', title: 'Tắt', emoji: '🎯', minutes: 7 * 60, weekday: 2, remind: false),
    ];
    final plan = planNotifications(
      settings: settings(greetings: false),
      good: [gym],
      bad: [],
      events: events,
      now: now,
    );
    expect(plan, hasLength(2));
    expect(plan[0].repeat, Repeat.weekly);
    expect(plan[0].title, '🚶 Đi bộ · 18:00');
    expect(plan[0].body, contains('Tập thể dục'));
    expect(plan[1].at, DateTime(2026, 10, 24, 19));
    expect(plan.every((p) => p.payload == 'calendar'), isTrue);
  });

  test('lời chào buổi sáng kèm dự báo thời tiết', () {
    final plan = planNotifications(
      settings: settings(),
      good: [],
      bad: [],
      morningForecast: 'có mưa rào, 25–32°c, khả năng mưa 70%',
      now: now,
    );
    expect(
      plan.first.body,
      'Hôm nay có mưa rào, 25–32°c, khả năng mưa 70%. Bắt đầu ngày mới bằng một ly nước nhé!',
    );
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
    expect(plan.firstWhere((p) => p.payload == 'craving:b').minutes, 870);
    final milestone = plan.firstWhere((p) => p.repeat == Repeat.once);
    expect(milestone.at, b.cleanSince.add(const Duration(days: 3)));
    expect(milestone.channel, PlannedNotification.channelMilestones);
  });

  test('không vượt quá giới hạn thông báo chờ của iOS', () {
    // Uống nước mỗi 30 phút cả ngày (48 lần) cộng 3 thói quen nhắc 5 ngày/tuần (15).
    final good = [
      water(HabitReminder.interval(every: 30, from: 0, to: 23 * 60 + 30)),
      for (var i = 0; i < 3; i++)
        GoodHabit(
          id: 'g$i',
          name: 'Thói quen $i',
          emoji: '⭐',
          reminder: HabitReminder(minutes: 600 + i, weekdays: {1, 2, 3, 4, 5}),
        ),
    ];
    final plan = planNotifications(settings: settings(), good: good, bad: [], now: now);
    expect(plan, hasLength(maxPlanned));
    expect(plan.take(2).map((p) => p.payload), ['home', 'home']);
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
}
