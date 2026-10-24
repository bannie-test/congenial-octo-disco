import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Trình duyệt không hỗ trợ đặt lịch thông báo; bản web chỉ để xem giao diện.
  final NotificationService notifications = kIsWeb
      ? PreviewNotificationService()
      : LocalNotificationService();
  try {
    await notifications.init();
  } catch (e) {
    debugPrint('Không khởi tạo được thông báo: $e');
  }
  final state = AppState(prefs: prefs, notifications: notifications)..load();
  runApp(MamApp(state: state));
  // Lịch cột mốc phụ thuộc thời gian, nên đặt lại mỗi lần mở app.
  unawaited(state.rescheduleNotifications());
}

/// Đưa [AppState] xuống cây widget; widget nào gọi [AppScope.of] sẽ
/// tự build lại khi state thay đổi.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class MamApp extends StatelessWidget {
  const MamApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Mầm',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: AppScope.of(context).onboarded ? const HomeScreen() : const OnboardingScreen(),
          ),
        ),
      ),
    );
  }
}
