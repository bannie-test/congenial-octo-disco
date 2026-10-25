import '../utils/format.dart';

/// Thứ trong tuần theo chuẩn [DateTime.weekday]: 1 = thứ hai … 7 = chủ nhật.
const allWeekdays = {1, 2, 3, 4, 5, 6, 7};

String describeWeekdays(Set<int> days) {
  if (days.length == 7) return 'Mỗi ngày';
  if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) return 'Ngày thường';
  if (days.length == 2 && days.containsAll({6, 7})) return 'Cuối tuần';
  final sorted = days.toList()..sort();
  return sorted.map((d) => weekdayShort[d - 1]).join(', ');
}

/// "90" -> "1 giờ 30 phút"
String formatEvery(int minutes) {
  if (minutes < 60) return '$minutes phút';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

/// Nhắc vào một giờ cố định, hoặc lặp lại theo chu kỳ trong một khung giờ.
enum ReminderMode { fixed, interval }

/// Nhắc nhở gắn với một thói quen.
class HabitReminder {
  HabitReminder({
    this.minutes = 20 * 60,
    this.enabled = true,
    Set<int>? weekdays,
    this.mode = ReminderMode.fixed,
    this.every = 120,
    this.from = 8 * 60,
    this.to = 20 * 60,
  }) : weekdays = weekdays ?? {...allWeekdays};

  /// Nhắc lặp lại, ví dụ uống nước mỗi 2 giờ từ 8:00 đến 20:00.
  HabitReminder.interval({int every = 120, int from = 8 * 60, int to = 20 * 60, Set<int>? weekdays})
    : this(mode: ReminderMode.interval, every: every, from: from, to: to, weekdays: weekdays, minutes: from);

  static const minEvery = 5;

  bool enabled;
  ReminderMode mode;

  /// Giờ nhắc (phút tính từ 0 giờ) khi [mode] là [ReminderMode.fixed].
  int minutes;

  /// Chu kỳ (phút) và khung giờ khi [mode] là [ReminderMode.interval].
  int every;
  int from;
  int to;

  final Set<int> weekdays;

  /// Các giờ nhắc trong một ngày.
  List<int> get slots {
    if (mode == ReminderMode.fixed) return [minutes];
    if (every < minEvery || to < from) return const [];
    return [for (var m = from; m <= to; m += every) m];
  }

  String get timeLabel => mode == ReminderMode.fixed
      ? formatHm(minutes)
      : 'Mỗi ${formatEvery(every)}, ${formatHm(from)}–${formatHm(to)}';

  String get label => '$timeLabel · ${describeWeekdays(weekdays)}';

  bool firesOn(int weekday) => enabled && weekdays.contains(weekday);

  HabitReminder copyWith({bool? enabled}) => HabitReminder(
    enabled: enabled ?? this.enabled,
    minutes: minutes,
    weekdays: {...weekdays},
    mode: mode,
    every: every,
    from: from,
    to: to,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'mode': mode.name,
    'minutes': minutes,
    'every': every,
    'from': from,
    'to': to,
    'weekdays': weekdays.toList()..sort(),
  };

  factory HabitReminder.fromJson(Map<String, dynamic> json) => HabitReminder(
    enabled: json['enabled'] as bool? ?? true,
    mode: ReminderMode.values.asNameMap()[json['mode']] ?? ReminderMode.fixed,
    minutes: (json['minutes'] as num).toInt(),
    every: (json['every'] as num?)?.toInt() ?? 120,
    from: (json['from'] as num?)?.toInt() ?? 8 * 60,
    to: (json['to'] as num?)?.toInt() ?? 20 * 60,
    weekdays: (json['weekdays'] as List).map((e) => (e as num).toInt()).toSet(),
  );
}

/// Cài đặt chung của cả app.
class ReminderSettings {
  /// Người dùng đã bật nhắc nhở hay chưa (khác với quyền của hệ điều hành).
  bool enabled = false;

  bool morning = true;
  int morningAt = 8 * 60;

  bool evening = true;
  int eveningAt = 21 * 60;

  bool milestones = true;

  /// Âm thanh hiệu ứng khi hoàn thành hoặc lỡ mục tiêu.
  bool sound = true;

  /// Nhắc uống nước của bản cũ (trước khi gộp vào thói quen uống nước).
  HabitReminder? legacyWater;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'morning': morning,
    'morningAt': morningAt,
    'evening': evening,
    'eveningAt': eveningAt,
    'milestones': milestones,
    'sound': sound,
  };

  void readJson(Map<String, dynamic> json) {
    enabled = json['enabled'] as bool? ?? enabled;
    morning = json['morning'] as bool? ?? morning;
    morningAt = (json['morningAt'] as num?)?.toInt() ?? morningAt;
    evening = json['evening'] as bool? ?? evening;
    eveningAt = (json['eveningAt'] as num?)?.toInt() ?? eveningAt;
    milestones = json['milestones'] as bool? ?? milestones;
    sound = json['sound'] as bool? ?? sound;
    if (json['water'] == true) {
      legacyWater = HabitReminder.interval(
        every: (json['waterEvery'] as num?)?.toInt() ?? 120,
        from: (json['waterFrom'] as num?)?.toInt() ?? 8 * 60,
        to: (json['waterTo'] as num?)?.toInt() ?? 20 * 60,
      );
    }
  }
}
