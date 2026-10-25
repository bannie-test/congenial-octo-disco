import '../models/habit.dart';
import '../models/journal.dart';
import '../models/reminder.dart';
import '../utils/format.dart';

enum Repeat { daily, weekly, once }

/// Một thông báo cần đặt lịch. Không phụ thuộc plugin nên dễ kiểm thử.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.repeat,
    this.channel = channelReminders,
    this.minutes = 0,
    this.weekday,
    this.at,
    this.payload = '',
  });

  static const channelReminders = 'reminders';
  static const channelMilestones = 'milestones';

  final int id;
  final String title;
  final String body;
  final Repeat repeat;
  final String channel;

  /// Giờ trong ngày (phút tính từ 0 giờ) cho [Repeat.daily] và [Repeat.weekly].
  final int minutes;

  /// Thứ trong tuần cho [Repeat.weekly].
  final int? weekday;

  /// Thời điểm cụ thể cho [Repeat.once].
  final DateTime? at;

  /// Dữ liệu trả về khi người dùng chạm vào thông báo.
  final String payload;

  bool firesOn(DateTime day) => switch (repeat) {
    Repeat.daily => true,
    Repeat.weekly => weekday == day.weekday,
    Repeat.once => at!.year == day.year && at!.month == day.month && at!.day == day.day,
  };

  /// Giờ trong ngày mà thông báo này sẽ hiện.
  int get minuteOfDay => repeat == Repeat.once ? at!.hour * 60 + at!.minute : minutes;
}

/// Các cột mốc "không tái phạm" được chúc mừng (tính theo ngày).
const cleanMilestones = [1, 3, 7, 14, 21, 30, 60, 90, 180, 365];

/// Các cột mốc chuỗi ngày liên tiếp của thói quen tốt.
const streakMilestones = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365];

const _waterLines = [
  'Một ngụm thôi cũng được, Mầm cũng đang khát nè!',
  'Uống một ly nước để đầu óc tỉnh táo hơn nhé.',
  'Một ly nước = một giọt mát lành cho Mầm 🌱',
  'Đứng dậy, vươn vai và uống chút nước nào!',
];

const _habitLines = [
  'Đến giờ rồi! Hoàn thành để tưới thêm một giọt cho Mầm 💧',
  'Chỉ cần bắt đầu thôi, phần còn lại sẽ dễ hơn.',
  'Mầm đang chờ bạn đó. Làm ngay nhé!',
];

/// iOS chỉ giữ 64 thông báo chờ, nên giới hạn ở mức an toàn.
const maxPlanned = 60;

/// Lập danh sách thông báo theo thứ tự ưu tiên: lời chào sáng/tối, lịch,
/// thói quen tốt, giờ hay thèm, rồi cột mốc. Vượt [limit] sẽ bị cắt bớt.
/// [morningForecast] là dự báo thời tiết gắn vào lời chào buổi sáng.
List<PlannedNotification> planNotifications({
  required ReminderSettings settings,
  required List<GoodHabit> good,
  required List<BadHabit> bad,
  required DateTime now,
  List<PlanEvent> events = const [],
  String? morningForecast,
  int limit = maxPlanned,
}) {
  if (!settings.enabled) return const [];
  final plan = <PlannedNotification>[];
  var nextId = 1;

  void add({
    required String title,
    required String body,
    required Repeat repeat,
    String channel = PlannedNotification.channelReminders,
    int minutes = 0,
    int? weekday,
    DateTime? at,
    String payload = '',
  }) {
    plan.add(
      PlannedNotification(
        id: nextId++,
        title: title,
        body: body,
        repeat: repeat,
        channel: channel,
        minutes: minutes,
        weekday: weekday,
        at: at,
        payload: payload,
      ),
    );
  }

  /// Mỗi giờ nhắc: hằng ngày nếu chọn đủ 7 ngày, ngược lại hằng tuần cho từng thứ.
  void addHabitReminder(HabitReminder r, String title, String Function(int i) body, String payload) {
    if (!r.enabled || r.weekdays.isEmpty) return;
    final slots = r.slots;
    for (var i = 0; i < slots.length; i++) {
      if (r.weekdays.length == 7) {
        add(title: title, body: body(i), repeat: Repeat.daily, minutes: slots[i], payload: payload);
        continue;
      }
      for (final d in r.weekdays.toList()..sort()) {
        add(
          title: title,
          body: body(i),
          repeat: Repeat.weekly,
          minutes: slots[i],
          weekday: d,
          payload: payload,
        );
      }
    }
  }

  if (settings.morning) {
    add(
      title: '☀️ Chào buổi sáng!',
      body: morningForecast == null
          ? 'Một ngày mới để Mầm lớn thêm. Bắt đầu từ thói quen nhỏ nhất nhé.'
          : 'Hôm nay $morningForecast. Bắt đầu ngày mới bằng một ly nước nhé!',
      repeat: Repeat.daily,
      minutes: settings.morningAt,
      payload: 'home',
    );
  }
  if (settings.evening) {
    add(
      title: '🌙 Tổng kết cuối ngày',
      body: 'Hôm nay bạn đã tưới Mầm đủ chưa? Ghé thăm Mầm một chút nhé.',
      repeat: Repeat.daily,
      minutes: settings.eveningAt,
      payload: 'home',
    );
  }

  for (final e in events) {
    if (!e.remind) continue;
    final habit = good.where((h) => h.id == e.habitId).firstOrNull;
    final body = habit == null
        ? 'Đến giờ theo lịch rồi, Mầm chờ bạn đó!'
        : 'Một bước cho thói quen "${habit.name}" 💪';
    final title = '${e.emoji} ${e.title} · ${formatHm(e.minutes)}';
    if (e.weekly) {
      add(
        title: title,
        body: body,
        repeat: Repeat.weekly,
        minutes: e.minutes,
        weekday: e.weekday,
        payload: 'calendar',
      );
    } else {
      final at = DateTime(e.date!.year, e.date!.month, e.date!.day, e.minutes ~/ 60, e.minutes % 60);
      if (at.isAfter(now)) add(title: title, body: body, repeat: Repeat.once, at: at, payload: 'calendar');
    }
  }

  for (var i = 0; i < good.length; i++) {
    final h = good[i];
    final r = h.reminder;
    if (r == null) continue;
    addHabitReminder(
      r,
      h.isWater ? '💧 Uống nước thôi!' : '${h.emoji} ${h.name}',
      (k) => h.isWater ? _waterLines[k % _waterLines.length] : _habitLines[(i + k) % _habitLines.length],
      'habit:${h.id}',
    );
  }

  for (final h in bad) {
    final r = h.reminder;
    if (r == null) continue;
    addHabitReminder(
      r,
      '${h.emoji} Sắp đến giờ hay thèm rồi',
      (_) => '"${h.name}": uống một ly nước và hít thở 1 phút nhé. Bạn làm được mà! 💪',
      'craving:${h.id}',
    );
  }

  if (settings.milestones) {
    for (final h in bad) {
      final days = h.cleanDays(now);
      final next = cleanMilestones.where((m) => m > days).firstOrNull;
      if (next == null) continue;
      final at = h.cleanSince.add(Duration(days: next));
      if (!at.isAfter(now)) continue;
      add(
        title: '🏆 Cột mốc $next ngày!',
        body: '"${h.name}": $next ngày không tái phạm. Mở app nhận lời chúc mừng từ Mầm nhé!',
        repeat: Repeat.once,
        channel: PlannedNotification.channelMilestones,
        at: at,
        payload: 'inbox',
      );
    }
  }

  return plan.length > limit ? plan.sublist(0, limit) : plan;
}

/// Các thông báo sẽ hiện trong ngày [day], sắp theo giờ.
List<PlannedNotification> notificationsOn(List<PlannedNotification> plan, DateTime day) =>
    plan.where((p) => p.firesOn(day)).toList()..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));

/// Thông báo kế tiếp sau thời điểm [now] (trong tuần tới).
({PlannedNotification item, DateTime at})? nextNotification(List<PlannedNotification> plan, DateTime now) {
  for (var offset = 0; offset < 8; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    for (final p in notificationsOn(plan, day)) {
      final at = p.repeat == Repeat.once
          ? p.at!
          : DateTime(day.year, day.month, day.day, p.minutes ~/ 60, p.minutes % 60);
      if (at.isAfter(now)) return (item: p, at: at);
    }
  }
  return null;
}

/// "14:00 · Uống nước thôi!" hoặc "Ngày mai 08:00 · …"
String describeNext(({PlannedNotification item, DateTime at}) next, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(next.at.year, next.at.month, next.at.day);
  final time = formatHm(next.at.hour * 60 + next.at.minute);
  final prefix = switch (day.difference(today).inDays) {
    0 => time,
    1 => 'Ngày mai $time',
    _ => '${weekdayNames[next.at.weekday - 1]} $time',
  };
  return '$prefix · ${next.item.title}';
}
