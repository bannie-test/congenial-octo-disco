import 'package:flutter_test/flutter_test.dart';
import 'package:mam/models/habit.dart';
import 'package:mam/state/app_state.dart';
import 'package:mam/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  AppState make({SharedPreferences? prefs}) => AppState(prefs: prefs, clock: () => now);

  setUp(() => now = DateTime(2026, 10, 24, 9));

  test('streak đếm từ hôm qua nếu hôm nay chưa làm', () {
    final h = GoodHabit(
      id: '1',
      name: 'Đọc',
      emoji: '📖',
      doneDays: {'2026-10-21', '2026-10-22', '2026-10-23'},
    );
    expect(h.streak(now), 3);
    h.doneDays.add('2026-10-24');
    expect(h.streak(now), 4);
    h.doneDays.remove('2026-10-22');
    expect(h.streak(now), 2);
  });

  test('toggleToday bật/tắt hoàn thành', () {
    final s = make()..addGoodHabit('Chạy', '🏃');
    final h = s.goodHabits.single;
    expect(s.toggleToday(h), isTrue);
    expect(s.doneTodayCount, 1);
    expect(s.toggleToday(h), isFalse);
    expect(s.doneTodayCount, 0);
  });

  test('tiền tiết kiệm và tái phạm', () {
    final s = make()..addBadHabit('Trà sữa', '🧋', costPerDay: 40000);
    final h = s.badHabits.single;
    now = now.add(const Duration(days: 2, hours: 12));
    expect(h.cleanDays(now), 2);
    expect(s.totalMoneySaved, 100000);

    final before = s.vitality;
    s.relapse(h);
    expect(h.cleanDays(now), 0);
    expect(s.totalMoneySaved, 0);
    expect(s.vitality, lessThan(before));
  });

  test('cấp độ tăng theo điểm', () {
    final s = make()..addGoodHabit('Nước', '💧');
    expect(s.stage, 0);
    s.goodHabits.single.doneDays.addAll(List.generate(12, (i) => 'd$i'));
    expect(s.growthPoints, 12);
    expect(s.stage, 2);
    expect(s.stageProgress, closeTo(2 / 15, 1e-9));
  });

  test('sức sống giảm khi bỏ bê thói quen', () {
    final s = make()..addGoodHabit('Nước', '💧');
    expect(s.vitality, closeTo(0.4, 1e-9));
    s.toggleToday(s.goodHabits.single);
    s.goodHabits.single.doneDays.add(dayKey(now.subtract(const Duration(days: 1))));
    expect(s.vitality, closeTo(1.0, 1e-9));
  });

  test('lưu và đọc lại từ SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = make(prefs: prefs)
      ..completeOnboarding(good: [goodHabitTemplates.first], bad: [badHabitTemplates.first]);
    s.toggleToday(s.goodHabits.single);

    final loaded = make(prefs: prefs)..load();
    expect(loaded.onboarded, isTrue);
    expect(loaded.goodHabits.single.isDoneOn(now), isTrue);
    expect(loaded.badHabits.single.costPerDay, 40000);
  });

  test('formatVnd', () {
    expect(formatVnd(0), '0đ');
    expect(formatVnd(1500), '1.500đ');
    expect(formatVnd(1234567), '1.234.567đ');
  });
}
