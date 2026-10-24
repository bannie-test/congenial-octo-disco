import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mam/main.dart';
import 'package:mam/state/app_state.dart';

// Màn hình có animation lặp vô hạn (mầm lắc lư) nên không dùng pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('onboarding gieo mầm rồi vào màn hình chính', (tester) async {
    // Kích thước iPhone 15 để kiểm tra bố cục như trên máy thật.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = AppState(clock: () => DateTime(2026, 10, 24, 9));
    await tester.pumpWidget(MamApp(state: state));

    expect(find.text('Chào bạn, mình là Mầm 🌱'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu'));
    await settle(tester);

    await tester.tap(find.textContaining('Uống đủ 2 lít nước'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await settle(tester);

    await tester.tap(find.textContaining('Trà sữa'));
    await tester.pump();
    await tester.tap(find.text('Gieo mầm 🌱'));
    await settle(tester);

    expect(state.onboarded, isTrue);
    expect(find.text('Mầm của bạn'), findsOneWidget);
    expect(find.text('Uống đủ 2 lít nước'), findsOneWidget);

    await tester.ensureVisible(find.text('Uống đủ 2 lít nước'));
    await tester.tap(find.text('Uống đủ 2 lít nước'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.doneTodayCount, 1);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
