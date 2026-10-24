import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';

typedef Clock = DateTime Function();

/// Trạng thái toàn app: danh sách thói quen, lưu xuống máy, và
/// tính toán độ lớn / sức sống của mầm cây.
class AppState extends ChangeNotifier {
  AppState({this._prefs, Clock? clock}) : _clock = clock ?? DateTime.now;

  static const _storageKey = 'mam_state_v1';

  /// Mốc điểm để mầm lên cấp: hạt → mầm → cây non → cây nhỏ → cây lớn → ra hoa.
  static const stageThresholds = [0, 3, 10, 25, 50, 100];
  static const stageNames = ['Hạt giống', 'Nảy mầm', 'Cây non', 'Cây nhỏ', 'Cây lớn', 'Ra hoa'];

  final SharedPreferences? _prefs;
  final Clock _clock;

  final List<GoodHabit> goodHabits = [];
  final List<BadHabit> badHabits = [];
  bool onboarded = false;

  DateTime get now => _clock();

  void load() {
    final raw = _prefs?.getString(_storageKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    onboarded = json['onboarded'] as bool? ?? false;
    goodHabits
      ..clear()
      ..addAll((json['good'] as List).map((e) => GoodHabit.fromJson(e as Map<String, dynamic>)));
    badHabits
      ..clear()
      ..addAll((json['bad'] as List).map((e) => BadHabit.fromJson(e as Map<String, dynamic>)));
  }

  void _save() {
    _prefs?.setString(
      _storageKey,
      jsonEncode({
        'onboarded': onboarded,
        'good': goodHabits.map((h) => h.toJson()).toList(),
        'bad': badHabits.map((h) => h.toJson()).toList(),
      }),
    );
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  String _newId() => '${now.microsecondsSinceEpoch}${math.Random().nextInt(999)}';

  void completeOnboarding({required List<HabitTemplate> good, required List<HabitTemplate> bad}) {
    for (final t in good) {
      goodHabits.add(GoodHabit(id: _newId(), name: t.name, emoji: t.emoji));
    }
    for (final t in bad) {
      badHabits.add(
        BadHabit(id: _newId(), name: t.name, emoji: t.emoji, cleanSince: now, costPerDay: t.costPerDay),
      );
    }
    onboarded = true;
    _changed();
  }

  void addGoodHabit(String name, String emoji) {
    goodHabits.add(GoodHabit(id: _newId(), name: name, emoji: emoji));
    _changed();
  }

  void addBadHabit(String name, String emoji, {int costPerDay = 0}) {
    badHabits.add(BadHabit(id: _newId(), name: name, emoji: emoji, cleanSince: now, costPerDay: costPerDay));
    _changed();
  }

  void removeGoodHabit(String id) {
    goodHabits.removeWhere((h) => h.id == id);
    _changed();
  }

  void removeBadHabit(String id) {
    badHabits.removeWhere((h) => h.id == id);
    _changed();
  }

  /// Bật/tắt trạng thái hoàn thành hôm nay. Trả về true nếu vừa hoàn thành.
  bool toggleToday(GoodHabit habit) {
    final key = dayKey(now);
    final done = !habit.doneDays.remove(key);
    if (done) habit.doneDays.add(key);
    _changed();
    return done;
  }

  void relapse(BadHabit habit) {
    habit.relapse(now);
    _changed();
  }

  int get doneTodayCount => goodHabits.where((h) => h.isDoneOn(now)).length;

  int get totalMoneySaved => badHabits.fold(0, (sum, h) => sum + h.moneySaved(now));

  /// Điểm tăng trưởng: mỗi lần hoàn thành thói quen tốt +1,
  /// mỗi ngày "sạch" của thói quen xấu +1.
  int get growthPoints =>
      goodHabits.fold<int>(0, (s, h) => s + h.doneDays.length) +
      badHabits.fold<int>(0, (s, h) => s + h.cleanDays(now));

  int get stage {
    final p = growthPoints;
    var s = 0;
    for (var i = 0; i < stageThresholds.length; i++) {
      if (p >= stageThresholds[i]) s = i;
    }
    return s;
  }

  /// Tiến độ trong cấp hiện tại (0..1), để vẽ mầm lớn dần mượt mà.
  double get stageProgress {
    final s = stage;
    if (s == stageThresholds.length - 1) return 1;
    final lo = stageThresholds[s];
    final hi = stageThresholds[s + 1];
    return (growthPoints - lo) / (hi - lo);
  }

  /// Sức sống của mầm (0.2..1): dựa vào tỉ lệ hoàn thành 3 ngày gần nhất
  /// và bị trừ nếu vừa tái phạm trong 24 giờ qua.
  double get vitality {
    var score = 1.0;
    if (goodHabits.isNotEmpty) {
      var done = 0;
      for (var i = 0; i < 3; i++) {
        final day = now.subtract(Duration(days: i));
        done += goodHabits.where((h) => h.isDoneOn(day)).length;
      }
      // Hôm nay chưa kết thúc nên chỉ tính 2 ngày trước làm mẫu số tối thiểu.
      final expected = goodHabits.length * 2;
      score = 0.4 + 0.6 * math.min(1, done / expected);
    }
    final relapsed = badHabits.where((h) => h.relapsedWithin(now, const Duration(hours: 24)));
    score -= 0.25 * relapsed.length;
    return score.clamp(0.2, 1.0);
  }

  String get moodMessage {
    final v = vitality;
    if (v > 0.85) return 'Mầm đang rất khỏe, giữ phong độ nhé!';
    if (v > 0.6) return 'Mầm ổn, thêm một thói quen nữa là tươi rói.';
    if (v > 0.4) return 'Mầm hơi khát, chăm nó một chút nhé.';
    return 'Mầm đang héo… không sao, bắt đầu lại từ hôm nay.';
  }
}
