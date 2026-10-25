import 'package:flutter_test/flutter_test.dart';
import 'package:mam/models/habit.dart';
import 'package:mam/models/reminder.dart';
import 'package:mam/services/sound_service.dart';
import 'package:mam/services/weather.dart';
import 'package:mam/state/app_state.dart';
import 'package:mam/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWeather implements WeatherService {
  int calls = 0;

  @override
  Future<Weather?> fetch(City city) async {
    calls++;
    return Weather(
      temp: 31,
      humidity: 78,
      code: 80,
      fetchedAt: DateTime(2026, 10, 24, 9),
      days: const [
        DayForecast(day: '2026-10-24', code: 80, min: 25, max: 32, rain: 70),
        DayForecast(day: '2026-10-25', code: 1, min: 24, max: 30, rain: 10),
      ],
    );
  }
}

void main() {
  late DateTime now;
  AppState make({SharedPreferences? prefs}) => AppState(prefs: prefs, clock: () => now);

  setUp(() => now = DateTime(2026, 10, 24, 9));

  test('streak đếm từ hôm qua nếu hôm nay chưa làm, và kỷ lục chuỗi', () {
    final h = GoodHabit(
      id: '1',
      name: 'Đọc',
      emoji: '📖',
      doneDays: {'2026-10-18', '2026-10-21', '2026-10-22', '2026-10-23'},
    );
    expect(h.streak(now), 3);
    h.doneDays.add('2026-10-24');
    expect(h.streak(now), 4);
    expect(h.bestStreak, 4);
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

  test('uống nước luôn có sẵn sau giới thiệu, kèm nhắc lặp lại', () {
    final s = make()..completeOnboarding(good: [goodHabitTemplates[1]], bad: []);
    final water = s.goodHabits.first;
    expect(water.isWater, isTrue);
    expect(water.reminder!.mode, ReminderMode.interval);
    expect(water.reminder!.slots, hasLength(7));
    expect(s.goodHabits, hasLength(2));
    expect(s.goal, 2);

    final off = make()..completeOnboarding(good: [], bad: [], waterReminder: false);
    expect(off.goodHabits.single.reminder!.enabled, isFalse);
  });

  test('mục tiêu ngày quyết định giọt nước hôm nay và sức sống', () {
    final s = make()..completeOnboarding(good: goodHabitTemplates.take(4).toList(), bad: []);
    expect(s.goal, 3);
    s.setDailyGoal(2);
    expect(s.goal, 2);
    s.toggleToday(s.goodHabits[0]);
    expect(s.todayProgress, 0.5);
    s.toggleToday(s.goodHabits[1]);
    expect(s.todayProgress, 1);
    expect(s.goalMetOn(now), isTrue);
    // Đạt mục tiêu hôm qua và hôm nay: Mầm đầy sức sống.
    for (final h in s.goodHabits.take(2)) {
      h.doneDays.add(dayKey(dayOffset(now, -1)));
    }
    expect(s.vitality, closeTo(1.0, 1e-9));
    s.setDailyGoal(99);
    expect(s.goal, 4);
  });

  test('tái phạm đặt lại bộ đếm và làm Mầm héo', () {
    final s = make()..addBadHabit('Trà sữa', '🧋');
    final h = s.badHabits.single;
    now = now.add(const Duration(days: 2, hours: 12));
    expect(h.cleanDays(now), 2);
    final before = s.vitality;
    s.relapse(h);
    expect(h.cleanDays(now), 0);
    expect(h.bestCleanDays(now), 0);
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

  test('lịch: sự kiện lặp hằng tuần và một lần', () {
    final s = make()..completeOnboarding(good: [goodHabitTemplates[3]], bad: []);
    final gym = s.goodHabits.last;
    // Thứ hai đi bộ, thứ ba đạp xe.
    s.addEvent(s.newEvent(title: 'Đi bộ', emoji: '🚶', minutes: 18 * 60, habitId: gym.id, weekday: 1));
    s.addEvent(s.newEvent(title: 'Đạp xe', emoji: '🚴', minutes: 18 * 60, habitId: gym.id, weekday: 2));
    s.addEvent(s.newEvent(title: 'Bơi', emoji: '🏊', minutes: 7 * 60, date: DateTime(2026, 10, 24)));
    expect(s.eventsOn(DateTime(2026, 10, 26)).single.title, 'Đi bộ');
    expect(s.eventsOn(DateTime(2026, 10, 27)).single.title, 'Đạp xe');
    expect(s.eventsOn(DateTime(2026, 10, 24)).single.title, 'Bơi');
    expect(s.eventsOn(DateTime(2026, 10, 31)), isEmpty);
    // Xoá thói quen thì xoá luôn lịch gắn với nó.
    s.removeGoodHabit(gym.id);
    expect(s.events.single.title, 'Bơi');
  });

  test('nhật ký cảm xúc', () {
    final s = make()..setMood(now, 'joy', '  Chạy bộ xong thấy khoẻ  ');
    expect(s.moodOn(now)!.mood.emoji, '😄');
    expect(s.moodOn(now)!.note, 'Chạy bộ xong thấy khoẻ');
    s.setMood(now, 'tired', '');
    expect(s.moods, hasLength(1));
    s.removeMood(dayKey(now));
    expect(s.moodOn(now), isNull);
  });

  test('thời tiết: cập nhật, lưu đệm và gắn dự báo vào lời chào sáng', () async {
    final service = _FakeWeather();
    final s = AppState(clock: () => now, weatherService: service)
      ..completeOnboarding(good: [], bad: [], enableReminders: true);
    now = DateTime(2026, 10, 24, 7);
    await s.refreshWeather();
    expect(s.weather!.temp, 31);
    expect(s.morningForecast, 'có mưa rào, 25–32°c, khả năng mưa 70%');
    await s.refreshWeather();
    expect(service.calls, 1, reason: 'chưa quá 30 phút thì dùng dữ liệu cũ');
    expect(s.plannedNotifications.first.body, contains('khả năng mưa 70%'));
    // Đã qua giờ chào sáng thì dùng dự báo ngày mai.
    now = DateTime(2026, 10, 24, 10);
    expect(s.morningForecast, contains('10%'));
  });

  test('âm thanh chỉ phát khi được bật', () {
    final sounds = SilentSoundService();
    final s = AppState(clock: () => now, sounds: sounds)..playSound(Sfx.drop);
    s.updateReminders((r) => r.sound = false);
    s.playSound(Sfx.success);
    expect(sounds.played, [Sfx.drop]);
  });

  test('lưu và đọc lại từ SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = make(prefs: prefs)..completeOnboarding(good: [], bad: [badHabitTemplates.first]);
    s.toggleToday(s.goodHabits.single);
    s.setDailyGoal(1);
    s.setMood(now, 'calm', 'Bình yên');
    s.addEvent(s.newEvent(title: 'Đi bộ', emoji: '🚶', minutes: 1080, weekday: 1));

    final loaded = make(prefs: prefs)..load();
    expect(loaded.onboarded, isTrue);
    expect(loaded.goodHabits.single.isDoneOn(now), isTrue);
    expect(loaded.goodHabits.single.reminder!.mode, ReminderMode.interval);
    expect(loaded.badHabits.single.reminder!.minutes, 14 * 60 + 30);
    expect(loaded.dailyGoal, 1);
    expect(loaded.moodOn(now)!.note, 'Bình yên');
    expect(loaded.events.single.weekday, 1);
  });

  test('định dạng', () {
    expect(formatHm(485), '08:05');
    expect(formatEvery(90), '1 giờ 30 phút');
    expect(formatEvery(45), '45 phút');
    expect(describeWeekdays({1, 2, 3, 4, 5}), 'Ngày thường');
    expect(describeWeekdays({1, 3}), 'T2, T4');
    expect(formatDate(now), 'Thứ bảy, 24/10');
  });
}
