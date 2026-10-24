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

/// Nhắc nhở gắn với một thói quen: giờ trong ngày và các thứ được nhắc.
class HabitReminder {
  HabitReminder({required this.minutes, this.enabled = true, Set<int>? weekdays})
    : weekdays = weekdays ?? {...allWeekdays};

  bool enabled;

  /// Số phút tính từ 0 giờ.
  int minutes;
  final Set<int> weekdays;

  String get label => '${formatHm(minutes)} · ${describeWeekdays(weekdays)}';

  bool firesOn(int weekday) => enabled && weekdays.contains(weekday);

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'minutes': minutes,
    'weekdays': weekdays.toList()..sort(),
  };

  factory HabitReminder.fromJson(Map<String, dynamic> json) => HabitReminder(
    enabled: json['enabled'] as bool? ?? true,
    minutes: (json['minutes'] as num).toInt(),
    weekdays: (json['weekdays'] as List).map((e) => (e as num).toInt()).toSet(),
  );
}

/// Cài đặt nhắc nhở chung của cả app.
class ReminderSettings {
  /// Người dùng đã bật nhắc nhở hay chưa (khác với quyền của hệ điều hành).
  bool enabled = false;

  bool morning = true;
  int morningAt = 8 * 60;

  bool evening = true;
  int eveningAt = 21 * 60;

  bool water = false;
  int waterEvery = 120;
  int waterFrom = 8 * 60;
  int waterTo = 20 * 60;

  bool milestones = true;

  static const waterIntervals = [30, 60, 90, 120, 180];

  /// Các giờ nhắc uống nước trong ngày (phút tính từ 0 giờ).
  List<int> get waterSlots {
    if (waterEvery <= 0 || waterTo < waterFrom) return const [];
    return [for (var m = waterFrom; m <= waterTo; m += waterEvery) m];
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'morning': morning,
    'morningAt': morningAt,
    'evening': evening,
    'eveningAt': eveningAt,
    'water': water,
    'waterEvery': waterEvery,
    'waterFrom': waterFrom,
    'waterTo': waterTo,
    'milestones': milestones,
  };

  void readJson(Map<String, dynamic> json) {
    enabled = json['enabled'] as bool? ?? enabled;
    morning = json['morning'] as bool? ?? morning;
    morningAt = (json['morningAt'] as num?)?.toInt() ?? morningAt;
    evening = json['evening'] as bool? ?? evening;
    eveningAt = (json['eveningAt'] as num?)?.toInt() ?? eveningAt;
    water = json['water'] as bool? ?? water;
    waterEvery = (json['waterEvery'] as num?)?.toInt() ?? waterEvery;
    waterFrom = (json['waterFrom'] as num?)?.toInt() ?? waterFrom;
    waterTo = (json['waterTo'] as num?)?.toInt() ?? waterTo;
    milestones = json['milestones'] as bool? ?? milestones;
  }
}
