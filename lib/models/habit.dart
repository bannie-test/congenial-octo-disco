import 'reminder.dart';

/// Chuyển một thời điểm thành khóa ngày dạng `yyyy-mm-dd` (theo giờ máy).
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Ngày (0 giờ) cách [d] một số ngày.
DateTime dayOffset(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

const waterEmoji = '💧';

/// Thói quen tốt: mỗi ngày chạm một lần để đánh dấu hoàn thành.
class GoodHabit {
  GoodHabit({required this.id, required this.name, required this.emoji, Set<String>? doneDays, this.reminder})
    : doneDays = doneDays ?? <String>{};

  final String id;
  final String name;
  final String emoji;

  /// Các ngày đã hoàn thành, dạng [dayKey].
  final Set<String> doneDays;

  HabitReminder? reminder;

  bool get isWater => emoji == waterEmoji;

  bool isDoneOn(DateTime day) => doneDays.contains(dayKey(day));

  /// Số ngày liên tiếp đã hoàn thành. Nếu hôm nay chưa làm thì đếm
  /// từ hôm qua, để chuỗi không bị "đứt" khi ngày mới vừa bắt đầu.
  int streak(DateTime now) => _streakRun(now).$1;

  /// Ngày bắt đầu của chuỗi hiện tại, dùng làm khóa để mỗi cột mốc
  /// của một chuỗi chỉ được chúc mừng một lần.
  String streakStartKey(DateTime now) => dayKey(_streakRun(now).$2);

  (int, DateTime) _streakRun(DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if (!isDoneOn(day)) day = dayOffset(day, -1);
    var count = 0;
    var start = day;
    while (isDoneOn(day)) {
      count++;
      start = day;
      day = dayOffset(day, -1);
    }
    return (count, start);
  }

  /// Chuỗi dài nhất từng đạt.
  int get bestStreak {
    final days = doneDays.map(DateTime.parse).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && dayOffset(prev, 1) == d ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'doneDays': doneDays.toList()..sort(),
    if (reminder != null) 'reminder': reminder!.toJson(),
  };

  factory GoodHabit.fromJson(Map<String, dynamic> json) => GoodHabit(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    doneDays: (json['doneDays'] as List).cast<String>().toSet(),
    reminder: json['reminder'] == null
        ? null
        : HabitReminder.fromJson(json['reminder'] as Map<String, dynamic>),
  );
}

/// Thói quen xấu đang cai: đếm thời gian "sạch" kể từ lần tái phạm gần nhất.
class BadHabit {
  BadHabit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cleanSince,
    List<DateTime>? relapses,
    this.reminder,
  }) : relapses = relapses ?? <DateTime>[];

  final String id;
  final String name;
  final String emoji;

  /// Bắt đầu chuỗi "sạch" hiện tại.
  DateTime cleanSince;

  final List<DateTime> relapses;

  /// Nhắc trước "giờ hay thèm" kèm một mẹo nhỏ để vượt qua.
  HabitReminder? reminder;

  Duration cleanFor(DateTime now) {
    final d = now.difference(cleanSince);
    return d.isNegative ? Duration.zero : d;
  }

  int cleanDays(DateTime now) => cleanFor(now).inDays;

  /// Chuỗi "sạch" dài nhất (ngày), tính cả chuỗi hiện tại.
  int bestCleanDays(DateTime now) {
    final sorted = [...relapses]..sort();
    var best = cleanDays(now);
    for (var i = 1; i < sorted.length; i++) {
      final d = sorted[i].difference(sorted[i - 1]).inDays;
      if (d > best) best = d;
    }
    return best;
  }

  bool relapsedWithin(DateTime now, Duration window) => relapses.any((r) => now.difference(r) < window);

  void relapse(DateTime now) {
    relapses.add(now);
    cleanSince = now;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'cleanSince': cleanSince.toIso8601String(),
    'relapses': relapses.map((r) => r.toIso8601String()).toList(),
    if (reminder != null) 'reminder': reminder!.toJson(),
  };

  factory BadHabit.fromJson(Map<String, dynamic> json) => BadHabit(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    cleanSince: DateTime.parse(json['cleanSince'] as String),
    relapses: (json['relapses'] as List).cast<String>().map(DateTime.parse).toList(),
    reminder: json['reminder'] == null
        ? null
        : HabitReminder.fromJson(json['reminder'] as Map<String, dynamic>),
  );
}

/// Gợi ý sẵn cho onboarding, gần gũi với người Việt.
class HabitTemplate {
  const HabitTemplate(this.emoji, this.name, {this.remindAt, this.every});
  final String emoji;
  final String name;

  /// Giờ nhắc gợi ý (phút tính từ 0 giờ). Với thói quen xấu là "giờ hay thèm".
  final int? remindAt;

  /// Nhắc lặp lại theo chu kỳ (phút), ví dụ uống nước.
  final int? every;

  HabitReminder? get reminder => every != null
      ? HabitReminder.interval(every: every!)
      : remindAt == null
      ? null
      : HabitReminder(minutes: remindAt!);
}

/// Uống nước là thói quen tốt mặc định, luôn có trong danh sách.
const waterTemplate = HabitTemplate(waterEmoji, 'Uống đủ 2 lít nước', every: 120);

const goodHabitTemplates = <HabitTemplate>[
  waterTemplate,
  HabitTemplate('🏃', 'Chạy bộ 20 phút', remindAt: 17 * 60 + 30),
  HabitTemplate('🚶', 'Đi bộ 30 phút', remindAt: 18 * 60),
  HabitTemplate('🏋️', 'Tập thể dục', remindAt: 6 * 60 + 30),
  HabitTemplate('📖', 'Đọc sách 10 trang', remindAt: 21 * 60 + 30),
  HabitTemplate('😴', 'Ngủ trước 12 giờ', remindAt: 23 * 60),
  HabitTemplate('🧘', 'Thiền 5 phút', remindAt: 7 * 60),
  HabitTemplate('🥗', 'Ăn rau mỗi bữa', remindAt: 11 * 60 + 30),
  HabitTemplate('✍️', 'Viết nhật ký', remindAt: 22 * 60),
  HabitTemplate('🇬🇧', 'Học tiếng Anh 15 phút', remindAt: 20 * 60),
];

const badHabitTemplates = <HabitTemplate>[
  HabitTemplate('🧋', 'Trà sữa', remindAt: 14 * 60 + 30),
  HabitTemplate('📱', 'Lướt TikTok quá đà', remindAt: 22 * 60 + 30),
  HabitTemplate('🚬', 'Hút thuốc', remindAt: 9 * 60 + 30),
  HabitTemplate('🍺', 'Rượu bia', remindAt: 18 * 60),
  HabitTemplate('🍟', 'Đồ ăn vặt', remindAt: 15 * 60 + 30),
  HabitTemplate('🛍️', 'Mua sắm bốc đồng', remindAt: 21 * 60),
  HabitTemplate('🎮', 'Chơi game thâu đêm', remindAt: 22 * 60),
  HabitTemplate('🤬', 'Nói tục'),
];
