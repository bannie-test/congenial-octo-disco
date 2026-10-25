import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import '../models/inbox_item.dart';
import '../models/journal.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/reminder_planner.dart';
import '../services/sound_service.dart';
import '../services/weather.dart';
import '../utils/format.dart';

typedef Clock = DateTime Function();

/// Trạng thái toàn app: thói quen, mục tiêu, lịch, cảm xúc, nhắc nhở,
/// hộp thông báo, thời tiết; lưu xuống máy và tính độ lớn / sức sống của Mầm.
class AppState extends ChangeNotifier {
  AppState({
    this._prefs,
    Clock? clock,
    NotificationService? notifications,
    WeatherService? weatherService,
    SoundService? sounds,
  }) : _clock = clock ?? DateTime.now,
       notifications = notifications ?? PreviewNotificationService(),
       _weatherService = weatherService ?? NoWeatherService(),
       sounds = sounds ?? SilentSoundService();

  static const _storageKey = 'mam_state_v1';
  static const _inboxLimit = 60;

  /// Mốc điểm để mầm lên cấp: hạt → mầm → cây non → cây nhỏ → cây lớn → ra hoa.
  static const stageThresholds = [0, 3, 10, 25, 50, 100];
  static const stageNames = ['Hạt giống', 'Nảy mầm', 'Cây non', 'Cây nhỏ', 'Cây lớn', 'Ra hoa'];

  final SharedPreferences? _prefs;
  final Clock _clock;
  final NotificationService notifications;
  final WeatherService _weatherService;
  final SoundService sounds;

  final List<GoodHabit> goodHabits = [];
  final List<BadHabit> badHabits = [];
  final ReminderSettings reminders = ReminderSettings();
  final List<PlanEvent> events = [];
  final Map<String, MoodEntry> moods = {};

  /// Thông báo trong app, mới nhất ở đầu.
  final List<InboxItem> inbox = [];

  /// Khóa của các sự kiện đã chúc mừng, để không báo trùng.
  final Set<String> _celebrated = {};

  bool onboarded = false;
  bool reminderPromptDismissed = false;

  /// Ngày bắt đầu dùng app, để không tính "lỡ mục tiêu" cho những ngày trước đó.
  DateTime? startedAt;

  /// Số thói quen tốt cần hoàn thành mỗi ngày.
  int dailyGoal = 3;

  int cityIndex = 0;
  Weather? weather;

  /// Quyền thông báo của hệ điều hành (null = chưa kiểm tra).
  bool? notificationsAllowed;

  final _events = StreamController<InboxItem>.broadcast();
  final List<InboxItem> _undelivered = [];

  DateTime get now => _clock();

  City get city => cities[cityIndex.clamp(0, cities.length - 1)];

  /// Các thông báo mới cần hiện banner trong app.
  Stream<InboxItem> get inboxEvents => _events.stream;

  /// Lấy các sự kiện phát sinh khi chưa có ai lắng nghe (ví dụ lúc mở app).
  List<InboxItem> takeUndelivered() {
    final items = List.of(_undelivered);
    _undelivered.clear();
    return items;
  }

  void load() {
    final raw = _prefs?.getString(_storageKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    List<Map<String, dynamic>> list(String key) =>
        ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    onboarded = json['onboarded'] as bool? ?? false;
    goodHabits
      ..clear()
      ..addAll(list('good').map(GoodHabit.fromJson));
    badHabits
      ..clear()
      ..addAll(list('bad').map(BadHabit.fromJson));
    if (json['reminders'] case final Map<String, dynamic> r) reminders.readJson(r);
    reminderPromptDismissed = json['reminderPromptDismissed'] as bool? ?? false;
    inbox
      ..clear()
      ..addAll(list('inbox').map(InboxItem.fromJson));
    events
      ..clear()
      ..addAll(list('events').map(PlanEvent.fromJson));
    moods
      ..clear()
      ..addEntries(list('moods').map(MoodEntry.fromJson).map((m) => MapEntry(m.day, m)));
    _celebrated
      ..clear()
      ..addAll(((json['celebrated'] as List?) ?? const []).cast<String>());
    dailyGoal = (json['dailyGoal'] as num?)?.toInt() ?? math.min(3, math.max(1, goodHabits.length));
    startedAt = json['startedAt'] == null ? null : DateTime.parse(json['startedAt'] as String);
    cityIndex = (json['city'] as num?)?.toInt() ?? 0;
    if (json['weather'] case final Map<String, dynamic> w) weather = Weather.fromJson(w);

    final migrated = _migrate(json);
    if (migrated) _collectEvents(silent: true);
    if (_collectEvents().isNotEmpty || migrated) _save();
  }

  /// Chuyển dữ liệu của bản cũ sang cấu trúc mới. Trả về true nếu có thay đổi.
  bool _migrate(Map<String, dynamic> json) {
    var changed = json['celebrated'] == null || json['startedAt'] == null;
    startedAt ??= now;
    // Nhắc uống nước trước đây là mục riêng, nay gộp vào thói quen uống nước.
    final legacy = reminders.legacyWater;
    if (legacy != null) {
      final water = goodHabits.where((h) => h.isWater).firstOrNull;
      if (water == null) {
        goodHabits.insert(
          0,
          GoodHabit(id: _newId(), name: waterTemplate.name, emoji: waterEmoji, reminder: legacy),
        );
      } else {
        water.reminder ??= legacy;
      }
      reminders.legacyWater = null;
      changed = true;
    }
    return changed;
  }

  void _save() {
    _prefs?.setString(
      _storageKey,
      jsonEncode({
        'onboarded': onboarded,
        'good': goodHabits.map((h) => h.toJson()).toList(),
        'bad': badHabits.map((h) => h.toJson()).toList(),
        'reminders': reminders.toJson(),
        'reminderPromptDismissed': reminderPromptDismissed,
        'inbox': inbox.map((i) => i.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'moods': moods.values.map((m) => m.toJson()).toList(),
        'celebrated': _celebrated.toList(),
        'dailyGoal': dailyGoal,
        'startedAt': startedAt?.toIso8601String(),
        'city': cityIndex,
        'weather': ?weather?.toJson(),
      }),
    );
  }

  void _changed({bool reschedule = false}) {
    _collectEvents();
    _save();
    if (reschedule) unawaited(rescheduleNotifications());
    notifyListeners();
  }

  String _newId() => '${now.microsecondsSinceEpoch}${math.Random().nextInt(999)}';

  void completeOnboarding({
    required List<HabitTemplate> good,
    required List<HabitTemplate> bad,
    bool enableReminders = false,
    bool waterReminder = true,
  }) {
    // Uống nước là thói quen tốt mặc định.
    final templates = [if (!good.any((t) => t.emoji == waterEmoji)) waterTemplate, ...good];
    for (final t in templates) {
      final reminder = t.reminder;
      if (t.emoji == waterEmoji && !waterReminder) reminder?.enabled = false;
      goodHabits.add(GoodHabit(id: _newId(), name: t.name, emoji: t.emoji, reminder: reminder));
    }
    for (final t in bad) {
      badHabits.add(
        BadHabit(id: _newId(), name: t.name, emoji: t.emoji, cleanSince: now, reminder: t.reminder),
      );
    }
    dailyGoal = math.min(3, goodHabits.length);
    startedAt = now;
    reminders.enabled = enableReminders;
    onboarded = true;
    _addInbox(
      InboxItem(
        id: 'welcome',
        kind: InboxKind.welcome,
        emoji: '🌱',
        title: 'Chào mừng bạn đến với Mầm!',
        body:
            'Chạm vào một thói quen để tưới nước cho Mầm. '
            'Mỗi ngày đạt mục tiêu, Mầm sẽ tươi tốt thêm một chút.',
        at: now,
      ),
    );
    _changed(reschedule: true);
  }

  void addGoodHabit(String name, String emoji, {HabitReminder? reminder}) {
    goodHabits.add(GoodHabit(id: _newId(), name: name, emoji: emoji, reminder: reminder));
    _changed(reschedule: true);
  }

  void addBadHabit(String name, String emoji, {HabitReminder? reminder}) {
    badHabits.add(BadHabit(id: _newId(), name: name, emoji: emoji, cleanSince: now, reminder: reminder));
    _changed(reschedule: true);
  }

  void removeGoodHabit(String id) {
    goodHabits.removeWhere((h) => h.id == id);
    events.removeWhere((e) => e.habitId == id);
    _changed(reschedule: true);
  }

  void removeBadHabit(String id) {
    badHabits.removeWhere((h) => h.id == id);
    _changed(reschedule: true);
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
    final before = habit.cleanFor(now);
    habit.relapse(now);
    _addInbox(
      InboxItem(
        id: 'relapse:${habit.id}:${now.toIso8601String()}',
        kind: InboxKind.relapse,
        emoji: '💙',
        title: 'Bắt đầu lại cũng là dũng cảm',
        body: 'Chuỗi vừa rồi với "${habit.name}": ${formatSpan(before)}. Lần này mình cùng đi xa hơn nhé!',
        at: now,
        read: true,
      ),
    );
    _changed(reschedule: true);
  }

  // ---------------------------------------------------------------------------
  // Mục tiêu

  /// Mục tiêu thực tế, không vượt quá số thói quen hiện có.
  int get goal => goodHabits.isEmpty ? 0 : dailyGoal.clamp(1, goodHabits.length);

  void setDailyGoal(int value) {
    dailyGoal = value.clamp(1, math.max(1, goodHabits.length));
    _changed();
  }

  int doneOn(DateTime day) => goodHabits.where((h) => h.isDoneOn(day)).length;

  bool goalMetOn(DateTime day) => goal > 0 && doneOn(day) >= goal;

  int get doneTodayCount => doneOn(now);

  /// Tiến độ mục tiêu hôm nay (0..1), dùng cho giọt nước trên màn hình chính.
  double get todayProgress => goal == 0 ? 0 : math.min(1, doneTodayCount / goal);

  // ---------------------------------------------------------------------------
  // Lịch và cảm xúc

  void addEvent(PlanEvent e) {
    events.add(e);
    _changed(reschedule: true);
  }

  PlanEvent newEvent({
    required String title,
    required String emoji,
    required int minutes,
    String? habitId,
    DateTime? date,
    int? weekday,
    bool remind = true,
  }) => PlanEvent(
    id: _newId(),
    title: title,
    emoji: emoji,
    minutes: minutes,
    habitId: habitId,
    date: date,
    weekday: weekday,
    remind: remind,
  );

  void removeEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _changed(reschedule: true);
  }

  List<PlanEvent> eventsOn(DateTime day) =>
      events.where((e) => e.occursOn(day)).toList()..sort((a, b) => a.minutes.compareTo(b.minutes));

  MoodEntry? moodOn(DateTime day) => moods[dayKey(day)];

  void setMood(DateTime day, String moodId, String note) {
    final key = dayKey(day);
    moods[key] = MoodEntry(day: key, moodId: moodId, note: note.trim(), at: now);
    _changed();
  }

  void removeMood(String day) {
    moods.remove(day);
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Thời tiết và âm thanh

  void setCity(int index) {
    cityIndex = index;
    weather = null;
    _changed();
    unawaited(refreshWeather(force: true));
  }

  /// Cập nhật thời tiết nếu dữ liệu đã cũ hơn 30 phút.
  Future<void> refreshWeather({bool force = false}) async {
    final w = weather;
    if (!force && w != null && now.difference(w.fetchedAt) < const Duration(minutes: 30)) return;
    try {
      final fresh = await _weatherService.fetch(city);
      if (fresh == null) return;
      weather = fresh;
      _changed(reschedule: true);
    } catch (e) {
      debugPrint('Không lấy được thời tiết: $e');
    }
  }

  /// Dự báo cho buổi sáng kế tiếp, gắn vào thông báo chào buổi sáng.
  String? get morningForecast {
    final t = now;
    final passed = t.hour * 60 + t.minute >= reminders.morningAt;
    return weather?.forecastFor(dayKey(passed ? dayOffset(t, 1) : t))?.summary.toLowerCase();
  }

  void playSound(Sfx sfx) {
    if (reminders.sound) unawaited(sounds.play(sfx));
  }

  // ---------------------------------------------------------------------------
  // Nhắc nhở

  void updateReminders(void Function(ReminderSettings r) edit) {
    edit(reminders);
    _changed(reschedule: true);
  }

  void setGoodReminder(GoodHabit habit, HabitReminder? reminder) {
    habit.reminder = reminder;
    _changed(reschedule: true);
  }

  void setBadReminder(BadHabit habit, HabitReminder? reminder) {
    habit.reminder = reminder;
    _changed(reschedule: true);
  }

  void dismissReminderPrompt() {
    reminderPromptDismissed = true;
    _changed();
  }

  /// Bật nhắc nhở: xin quyền hệ điều hành rồi đặt lịch.
  Future<bool> enableReminders() async {
    final granted = await notifications.requestPermission();
    notificationsAllowed = granted;
    reminders.enabled = true;
    _changed(reschedule: true);
    return granted;
  }

  Future<void> refreshPermission() async {
    final allowed = await notifications.isPermissionGranted();
    if (allowed == notificationsAllowed) return;
    notificationsAllowed = allowed;
    notifyListeners();
  }

  List<PlannedNotification> get plannedNotifications => planNotifications(
    settings: reminders,
    good: goodHabits,
    bad: badHabits,
    events: events,
    morningForecast: morningForecast,
    now: now,
  );

  bool _rescheduling = false;
  bool _rescheduleAgain = false;

  /// Đặt lại toàn bộ lịch. Các lần gọi dồn dập được gộp lại, chạy tuần tự.
  Future<void> rescheduleNotifications() async {
    if (_rescheduling) {
      _rescheduleAgain = true;
      return;
    }
    _rescheduling = true;
    try {
      do {
        _rescheduleAgain = false;
        await notifications.apply(plannedNotifications);
      } while (_rescheduleAgain);
    } catch (e) {
      debugPrint('Không đặt được lịch nhắc: $e');
    } finally {
      _rescheduling = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Hộp thông báo

  int get unreadCount => inbox.where((i) => !i.read).length;

  void markAllRead() {
    if (unreadCount == 0) return;
    for (final i in inbox) {
      i.read = true;
    }
    _changed();
  }

  void markRead(InboxItem item) {
    if (item.read) return;
    item.read = true;
    _changed();
  }

  void removeInbox(String id) {
    inbox.removeWhere((i) => i.id == id);
    _changed();
  }

  void _addInbox(InboxItem item) {
    inbox.removeWhere((i) => i.id == item.id);
    inbox.insert(0, item);
    if (inbox.length > _inboxLimit) inbox.removeRange(_inboxLimit, inbox.length);
  }

  /// Kiểm tra các cột mốc phụ thuộc thời gian (ví dụ qua nửa đêm là thêm
  /// một ngày "sạch"). Gọi định kỳ khi app đang mở.
  void refreshEvents() {
    if (_collectEvents().isEmpty) return;
    _save();
    notifyListeners();
  }

  /// Tìm các sự kiện mới: lên cấp, chuỗi ngày, cột mốc không tái phạm, đạt
  /// hoặc lỡ mục tiêu ngày. Mỗi sự kiện chỉ báo một lần.
  List<InboxItem> _collectEvents({bool silent = false}) {
    if (!onboarded) return const [];
    final fresh = <InboxItem>[];
    final t = now;

    /// Đánh dấu các mốc đã đạt; chỉ báo mốc cao nhất để không dội nhiều thông báo.
    void reach(List<String> keys, InboxItem Function() build) {
      if (keys.isEmpty) return;
      final isNew = !_celebrated.contains(keys.last);
      _celebrated.addAll(keys);
      if (isNew && !silent) fresh.add(build());
    }

    final s = stage;
    if (s > 0) {
      reach([for (var i = 1; i <= s; i++) 'stage:$i'], () {
        return InboxItem(
          id: 'stage:$s',
          kind: InboxKind.level,
          emoji: s == stageNames.length - 1 ? '🌸' : '🌿',
          title: 'Mầm lên cấp ${s + 1}: ${stageNames[s]}!',
          body: 'Cảm ơn bạn đã chăm sóc Mầm mỗi ngày. Nhìn xem Mầm đã lớn thế nào kìa!',
          at: t,
        );
      });
    }

    for (final h in goodHabits) {
      final streak = h.streak(t);
      final reached = streakMilestones.where((m) => m <= streak).toList();
      if (reached.isEmpty) continue;
      final start = h.streakStartKey(t);
      reach([for (final m in reached) 'streak:${h.id}:$start:$m'], () {
        final m = reached.last;
        return InboxItem(
          id: 'streak:${h.id}:$start:$m',
          kind: InboxKind.streak,
          emoji: '🔥',
          title: '$m ngày liên tiếp!',
          body: '${h.emoji} ${h.name}: bạn đã giữ chuỗi $m ngày. Thói quen đang thành nếp rồi đó!',
          at: t,
        );
      });
    }

    for (final h in badHabits) {
      final days = h.cleanDays(t);
      final reached = cleanMilestones.where((m) => m <= days).toList();
      if (reached.isEmpty) continue;
      final since = h.cleanSince.toIso8601String();
      reach([for (final m in reached) 'clean:${h.id}:$since:$m'], () {
        final m = reached.last;
        return InboxItem(
          id: 'clean:${h.id}:$since:$m',
          kind: InboxKind.clean,
          emoji: '🏆',
          title: 'Cột mốc $m ngày!',
          body: '"${h.name}": $m ngày không tái phạm. Mầm tự hào về bạn!',
          at: t,
        );
      });
    }

    final today = dayKey(t);
    // Khóa theo ngày chỉ cần giữ vài ngày gần nhất.
    final yesterday = dayKey(dayOffset(t, -1));
    _celebrated.removeWhere(
      (k) =>
          (k.startsWith('full:') || k.startsWith('missed:')) && !k.endsWith(today) && !k.endsWith(yesterday),
    );
    if (goalMetOn(t)) {
      reach(['full:$today'], () {
        final done = doneTodayCount;
        return InboxItem(
          id: 'full:$today',
          kind: InboxKind.daily,
          emoji: '💧',
          title: 'Đạt mục tiêu hôm nay!',
          body: 'Bạn hoàn thành $done/$goal thói quen. Mầm đang uống nước no nê 😋',
          at: t,
        );
      });
    }

    // Hôm qua lỡ mục tiêu (chỉ tính từ ngày bắt đầu dùng app).
    final y = dayOffset(t, -1);
    final start = startedAt;
    if (goal > 0 &&
        start != null &&
        !y.isBefore(DateTime(start.year, start.month, start.day)) &&
        !goalMetOn(y)) {
      reach(['missed:$yesterday'], () {
        return InboxItem(
          id: 'missed:$yesterday',
          kind: InboxKind.missed,
          emoji: '🥀',
          title: 'Hôm qua Mầm hơi khát',
          body: 'Bạn hoàn thành ${doneOn(y)}/$goal thói quen. Hôm nay mình cùng bù lại nhé!',
          at: t,
        );
      });
    }

    for (final item in fresh) {
      _addInbox(item);
      if (_events.hasListener) {
        _events.add(item);
      } else {
        _undelivered.add(item);
      }
    }
    return fresh;
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Mầm

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

  /// Sức sống của mầm (0.2..1): mức đạt mục tiêu ngày trong 3 ngày gần nhất,
  /// bị trừ nếu vừa tái phạm trong 24 giờ qua.
  double get vitality {
    var score = 1.0;
    if (goal > 0) {
      var total = 0.0;
      for (var i = 0; i < 3; i++) {
        total += math.min(1, doneOn(dayOffset(now, -i)) / goal);
      }
      // Hôm nay chưa kết thúc nên chỉ cần 2 ngày đạt mục tiêu là đầy sức sống.
      score = 0.4 + 0.6 * math.min(1, total / 2);
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
