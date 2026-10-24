/// Chuyển một thời điểm thành khóa ngày dạng `yyyy-mm-dd` (theo giờ máy).
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Thói quen tốt: mỗi ngày chạm một lần để đánh dấu hoàn thành.
class GoodHabit {
  GoodHabit({required this.id, required this.name, required this.emoji, Set<String>? doneDays})
    : doneDays = doneDays ?? <String>{};

  final String id;
  final String name;
  final String emoji;

  /// Các ngày đã hoàn thành, dạng [dayKey].
  final Set<String> doneDays;

  bool isDoneOn(DateTime day) => doneDays.contains(dayKey(day));

  /// Số ngày liên tiếp đã hoàn thành. Nếu hôm nay chưa làm thì đếm
  /// từ hôm qua, để chuỗi không bị "đứt" khi ngày mới vừa bắt đầu.
  int streak(DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if (!isDoneOn(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (isDoneOn(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'doneDays': doneDays.toList()..sort(),
  };

  factory GoodHabit.fromJson(Map<String, dynamic> json) => GoodHabit(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    doneDays: (json['doneDays'] as List).cast<String>().toSet(),
  );
}

/// Thói quen xấu đang cai: đếm thời gian "sạch" kể từ lần tái phạm gần nhất.
class BadHabit {
  BadHabit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cleanSince,
    this.costPerDay = 0,
    List<DateTime>? relapses,
  }) : relapses = relapses ?? <DateTime>[];

  final String id;
  final String name;
  final String emoji;

  /// Bắt đầu chuỗi "sạch" hiện tại.
  DateTime cleanSince;

  /// Số tiền (VNĐ) trung bình tiêu cho thói quen này mỗi ngày.
  final int costPerDay;

  final List<DateTime> relapses;

  Duration cleanFor(DateTime now) {
    final d = now.difference(cleanSince);
    return d.isNegative ? Duration.zero : d;
  }

  int cleanDays(DateTime now) => cleanFor(now).inDays;

  /// Tiền tiết kiệm được trong chuỗi hiện tại, tính theo từng giờ.
  int moneySaved(DateTime now) => (costPerDay * cleanFor(now).inMinutes / Duration.minutesPerDay).floor();

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
    'costPerDay': costPerDay,
    'relapses': relapses.map((r) => r.toIso8601String()).toList(),
  };

  factory BadHabit.fromJson(Map<String, dynamic> json) => BadHabit(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    cleanSince: DateTime.parse(json['cleanSince'] as String),
    costPerDay: (json['costPerDay'] as num?)?.toInt() ?? 0,
    relapses: (json['relapses'] as List).cast<String>().map(DateTime.parse).toList(),
  );
}

/// Gợi ý sẵn cho onboarding, gần gũi với người Việt.
class HabitTemplate {
  const HabitTemplate(this.emoji, this.name, {this.costPerDay = 0});
  final String emoji;
  final String name;
  final int costPerDay;
}

const goodHabitTemplates = <HabitTemplate>[
  HabitTemplate('💧', 'Uống đủ 2 lít nước'),
  HabitTemplate('🏃', 'Vận động 20 phút'),
  HabitTemplate('📖', 'Đọc sách 10 trang'),
  HabitTemplate('😴', 'Ngủ trước 12 giờ'),
  HabitTemplate('🧘', 'Thiền 5 phút'),
  HabitTemplate('🥗', 'Ăn rau mỗi bữa'),
  HabitTemplate('✍️', 'Viết nhật ký'),
  HabitTemplate('🇬🇧', 'Học tiếng Anh 15 phút'),
];

const badHabitTemplates = <HabitTemplate>[
  HabitTemplate('🧋', 'Trà sữa', costPerDay: 40000),
  HabitTemplate('📱', 'Lướt TikTok quá đà'),
  HabitTemplate('🚬', 'Hút thuốc', costPerDay: 30000),
  HabitTemplate('🍺', 'Rượu bia', costPerDay: 80000),
  HabitTemplate('🍟', 'Đồ ăn vặt', costPerDay: 25000),
  HabitTemplate('🛍️', 'Mua sắm bốc đồng', costPerDay: 100000),
  HabitTemplate('🎮', 'Chơi game thâu đêm'),
  HabitTemplate('🤬', 'Nói tục'),
];
