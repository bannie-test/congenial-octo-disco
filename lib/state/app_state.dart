import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import '../models/inbox_item.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/reminder_planner.dart';
import '../utils/format.dart';

typedef Clock = DateTime Function();

/// Trạng thái toàn app: danh sách thói quen, nhắc nhở, hộp thông báo,
/// lưu xuống máy, và tính toán độ lớn / sức sống của mầm cây.
class AppState extends ChangeNotifier {
  AppState({this._prefs, Clock? clock, NotificationService? notifications})
    : _clock = clock ?? DateTime.now,
      notifications = notifications ?? PreviewNotificationService();

  static const _storageKey = 'mam_state_v1';
  static const _inboxLimit = 60;

  /// Mốc điểm để mầm lên cấp: hạt → mầm → cây non → cây nhỏ → cây lớn → ra hoa.
  static const stageThresholds = [0, 3, 10, 25, 50, 100];
  static const stageNames = ['Hạt giống', 'Nảy mầm', 'Cây non', 'Cây nhỏ', 'Cây lớn', 'Ra hoa'];

  final SharedPreferences? _prefs;
  final Clock _clock;
  final NotificationService notifications;

  final List<GoodHabit> goodHabits = [];
  final List<BadHabit> badHabits = [];
  final ReminderSettings reminders = ReminderSettings();

  /// Thông báo trong app, mới nhất ở đầu.
  final List<InboxItem> inbox = [];

  /// Khóa của các sự kiện đã chúc mừng, để không báo trùng.
  final Set<String> _celebrated = {};

  bool onboarded = false;
  bool reminderPromptDismissed = false;

  /// Quyền thông báo của hệ điều hành (null = chưa kiểm tra).
  bool? notificationsAllowed;

  final _events = StreamController<InboxItem>.broadcast();
  final List<InboxItem> _undelivered = [];

  DateTime get now => _clock();

  /// Các thông báo mới cần hiện banner trong app.
  Stream<InboxItem> get events => _events.stream;

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
    onboarded = json['onboarded'] as bool? ?? false;
    goodHabits
      ..clear()
      ..addAll((json['good'] as List).map((e) => GoodHabit.fromJson(e as Map<String, dynamic>)));
    badHabits
      ..clear()
      ..addAll((json['bad'] as List).map((e) => BadHabit.fromJson(e as Map<String, dynamic>)));
    if (json['reminders'] case final Map<String, dynamic> r) reminders.readJson(r);
    reminderPromptDismissed = json['reminderPromptDismissed'] as bool? ?? false;
    inbox
      ..clear()
      ..addAll(
        ((json['inbox'] as List?) ?? const []).map((e) => InboxItem.fromJson(e as Map<String, dynamic>)),
      );
    _celebrated
      ..clear()
      ..addAll(((json['celebrated'] as List?) ?? const []).cast<String>());
    // Dữ liệu từ bản cũ chưa có lịch sử chúc mừng: ghi nhận im lặng những gì
    // đã đạt, tránh dội một loạt thông báo ngay lần mở đầu tiên.
    final migrated = json['celebrated'] == null;
    if (migrated) _collectEvents(silent: true);
    if (_collectEvents().isNotEmpty || migrated) _save();
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
        'celebrated': _celebrated.toList(),
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
  }) {
    HabitReminder? reminderFor(HabitTemplate t) =>
        t.remindAt == null ? null : HabitReminder(minutes: t.remindAt!);
    for (final t in good) {
      goodHabits.add(GoodHabit(id: _newId(), name: t.name, emoji: t.emoji, reminder: reminderFor(t)));
    }
    for (final t in bad) {
      badHabits.add(
        BadHabit(
          id: _newId(),
          name: t.name,
          emoji: t.emoji,
          cleanSince: now,
          costPerDay: t.costPerDay,
          reminder: reminderFor(t),
        ),
      );
    }
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
            'Mỗi ngày không tái phạm, Mầm sẽ khỏe thêm một chút.',
        at: now,
      ),
    );
    _changed(reschedule: true);
  }

  void addGoodHabit(String name, String emoji, {HabitReminder? reminder}) {
    goodHabits.add(GoodHabit(id: _newId(), name: name, emoji: emoji, reminder: reminder));
    _changed(reschedule: true);
  }

  void addBadHabit(String name, String emoji, {int costPerDay = 0, HabitReminder? reminder}) {
    badHabits.add(
      BadHabit(
        id: _newId(),
        name: name,
        emoji: emoji,
        cleanSince: now,
        costPerDay: costPerDay,
        reminder: reminder,
      ),
    );
    _changed(reschedule: true);
  }

  void removeGoodHabit(String id) {
    goodHabits.removeWhere((h) => h.id == id);
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

  List<PlannedNotification> get plannedNotifications =>
      planNotifications(settings: reminders, good: goodHabits, bad: badHabits, now: now);

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

  /// Tìm các thành tích mới: lên cấp, chuỗi ngày, cột mốc không tái phạm,
  /// hoàn thành đủ thói quen trong ngày. Mỗi sự kiện chỉ báo một lần.
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
        final saved = h.moneySaved(t);
        return InboxItem(
          id: 'clean:${h.id}:$since:$m',
          kind: InboxKind.clean,
          emoji: '🏆',
          title: 'Cột mốc $m ngày!',
          body:
              '"${h.name}": $m ngày không tái phạm'
              '${saved > 0 ? ', tiết kiệm được ${formatVnd(saved)}' : ''}. Mầm tự hào về bạn!',
          at: t,
        );
      });
    }

    final today = dayKey(t);
    if (goodHabits.isNotEmpty && doneTodayCount == goodHabits.length) {
      // Khóa theo ngày chỉ cần giữ của hôm nay.
      _celebrated.removeWhere((k) => k.startsWith('full:') && k != 'full:$today');
      reach(['full:$today'], () {
        final n = goodHabits.length;
        return InboxItem(
          id: 'full:$today',
          kind: InboxKind.daily,
          emoji: '💧',
          title: 'Đã tưới đủ cho Mầm hôm nay!',
          body: 'Bạn hoàn thành $n/$n thói quen. Mầm đang uống nước no nê 😋',
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

  int get doneTodayCount => goodHabits.where((h) => h.isDoneOn(now)).length;

  /// Tỉ lệ hoàn thành hôm nay (0..1), dùng cho giọt nước trên màn hình chính.
  double get todayProgress => goodHabits.isEmpty ? 0 : doneTodayCount / goodHabits.length;

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
