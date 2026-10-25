import 'package:flutter/painting.dart';

import '../utils/format.dart';
import 'habit.dart';

/// Một sự kiện trong lịch, ví dụ "Thứ hai đi bộ, thứ ba đạp xe" cho thói quen tập thể dục.
class PlanEvent {
  PlanEvent({
    required this.id,
    required this.title,
    required this.emoji,
    required this.minutes,
    this.habitId,
    this.date,
    this.weekday,
    this.remind = true,
  }) : assert(date != null || weekday != null);

  final String id;
  final String title;
  final String emoji;

  /// Thói quen tốt mà sự kiện này phục vụ (nếu có).
  final String? habitId;

  /// Sự kiện một lần vào ngày này (chỉ dùng phần ngày).
  final DateTime? date;

  /// Hoặc lặp lại hằng tuần vào thứ này.
  final int? weekday;

  /// Giờ (phút tính từ 0 giờ).
  final int minutes;
  final bool remind;

  bool get weekly => weekday != null;

  bool occursOn(DateTime day) => weekly ? day.weekday == weekday : dayKey(date!) == dayKey(day);

  String get repeatLabel => weekly ? 'Mỗi ${weekdayNames[weekday! - 1].toLowerCase()}' : 'Một lần';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'minutes': minutes,
    'habitId': ?habitId,
    if (date != null) 'date': dayKey(date!),
    'weekday': ?weekday,
    'remind': remind,
  };

  factory PlanEvent.fromJson(Map<String, dynamic> json) => PlanEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    emoji: json['emoji'] as String,
    minutes: (json['minutes'] as num).toInt(),
    habitId: json['habitId'] as String?,
    date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
    weekday: (json['weekday'] as num?)?.toInt(),
    remind: json['remind'] as bool? ?? true,
  );
}

/// Một loại cảm xúc chủ đạo trong ngày. [score] 1..5 dùng cho biểu đồ.
class Mood {
  const Mood(this.id, this.emoji, this.label, this.score, this.color);
  final String id;
  final String emoji;
  final String label;
  final int score;
  final Color color;
}

const moods = <Mood>[
  Mood('joy', '😄', 'Vui vẻ', 5, Color(0xFFFFC94D)),
  Mood('excited', '🤩', 'Hào hứng', 5, Color(0xFFFF9F43)),
  Mood('grateful', '🥰', 'Biết ơn', 5, Color(0xFFFF8FB1)),
  Mood('calm', '😌', 'Bình yên', 4, Color(0xFF7BD88F)),
  Mood('tired', '😴', 'Mệt mỏi', 2, Color(0xFFA9B4C2)),
  Mood('anxious', '😟', 'Lo âu', 2, Color(0xFFB39DDB)),
  Mood('sad', '😢', 'Buồn', 1, Color(0xFF6FA8DC)),
  Mood('angry', '😠', 'Tức giận', 1, Color(0xFFEF6F6C)),
];

Mood moodById(String id) => moods.firstWhere((m) => m.id == id, orElse: () => moods[3]);

/// Nhật ký cảm xúc của một ngày.
class MoodEntry {
  MoodEntry({required this.day, required this.moodId, this.note = '', required this.at});

  /// Khóa ngày dạng [dayKey].
  final String day;
  final String moodId;
  final String note;
  final DateTime at;

  Mood get mood => moodById(moodId);

  Map<String, dynamic> toJson() => {'day': day, 'mood': moodId, 'note': note, 'at': at.toIso8601String()};

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
    day: json['day'] as String,
    moodId: json['mood'] as String,
    note: json['note'] as String? ?? '',
    at: DateTime.parse(json['at'] as String),
  );
}
