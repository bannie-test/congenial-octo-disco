import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';

/// Lớp trung gian giữa app và hệ thống thông báo của điện thoại.
abstract class NotificationService {
  Future<void> init();

  /// Hệ điều hành có cho phép app hiện thông báo không.
  Future<bool> isPermissionGranted();

  /// Hiện hộp thoại xin quyền của hệ điều hành.
  Future<bool> requestPermission();

  /// Mở trang cài đặt thông báo của app. Trả về false nếu không hỗ trợ.
  Future<bool> openSettings();

  /// Thay toàn bộ lịch nhắc đang chờ bằng [plan].
  Future<void> apply(List<PlannedNotification> plan);

  Future<void> showNow({required String title, required String body});

  /// Payload của thông báo người dùng vừa chạm vào khi app đang chạy.
  Stream<String> get taps;

  /// Payload của thông báo đã mở app (nếu app được mở từ thông báo).
  Future<String?> launchPayload();
}

/// Dùng cho web và kiểm thử: không gửi gì thật, chỉ ghi lại lịch đã đặt.
class PreviewNotificationService implements NotificationService {
  PreviewNotificationService({this.granted = true});

  bool granted;
  List<PlannedNotification> applied = const [];
  final shown = <String>[];
  final _taps = StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<bool> isPermissionGranted() async => granted;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<bool> openSettings() async => false;

  @override
  Future<void> apply(List<PlannedNotification> plan) async => applied = plan;

  @override
  Future<void> showNow({required String title, required String body}) async => shown.add(title);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async => null;

  /// Giả lập người dùng chạm vào một thông báo.
  void simulateTap(String payload) => _taps.add(payload);
}

/// Thông báo thật trên Android và iOS qua `flutter_local_notifications`.
class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();

  static const _waterBlue = Color(0xFF1E9BE6);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Một số máy trả về tên múi giờ lạ; người dùng chính ở Việt Nam.
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Không xin quyền ngay khi mở app: để màn giới thiệu giải thích trước.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _taps.add(response.payload ?? ''),
    );
  }

  @override
  Future<bool> isPermissionGranted() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _android?.areNotificationsEnabled() ?? false;
      case TargetPlatform.iOS:
        return (await _ios?.checkPermissions())?.isEnabled ?? false;
      default:
        return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _android?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
        return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      default:
        return false;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _plugin.openAppNotificationSettings() ?? false;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails _details(String channel, String body) {
    final milestones = channel == PlannedNotification.channelMilestones;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        milestones ? 'Thành tích' : 'Nhắc nhở',
        channelDescription: milestones
            ? 'Chúc mừng khi bạn đạt cột mốc mới'
            : 'Nhắc thói quen, uống nước và lời chào mỗi ngày',
        importance: Importance.high,
        priority: Priority.high,
        color: _waterBlue,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  /// Lần xuất hiện kế tiếp của một lịch nhắc, theo múi giờ của máy.
  tz.TZDateTime _nextInstance(PlannedNotification p) {
    if (p.repeat == Repeat.once) return tz.TZDateTime.from(p.at!, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    final hour = p.minutes ~/ 60;
    final minute = p.minutes % 60;
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (!t.isAfter(now) || (p.weekday != null && t.weekday != p.weekday)) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, hour, minute);
    }
    return t;
  }

  @override
  Future<void> apply(List<PlannedNotification> plan) async {
    // Chỉ hủy lịch đang chờ, giữ nguyên thông báo đã hiện trên thanh trạng thái.
    await _plugin.cancelAllPendingNotifications();
    for (final p in plan) {
      await _plugin.zonedSchedule(
        id: p.id,
        title: p.title,
        body: p.body,
        payload: p.payload,
        scheduledDate: _nextInstance(p),
        notificationDetails: _details(p.channel, p.body),
        // Nhắc nhở không cần chính xác từng giây, nên không phải xin quyền báo thức chính xác.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: switch (p.repeat) {
          Repeat.daily => DateTimeComponents.time,
          Repeat.weekly => DateTimeComponents.dayOfWeekAndTime,
          Repeat.once => null,
        },
      );
    }
  }

  @override
  Future<void> showNow({required String title, required String body}) => _plugin.show(
    id: 0,
    title: title,
    body: body,
    notificationDetails: _details(PlannedNotification.channelReminders, body),
    payload: 'home',
  );

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}
