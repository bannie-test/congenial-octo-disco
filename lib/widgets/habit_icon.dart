import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'liquid.dart';

/// Góc nghiêng của điện thoại (radian, dương = nghiêng sang phải) đọc từ
/// gia tốc kế. Chỉ lắng nghe cảm biến khi có widget cần dùng.
abstract final class TiltSensor {
  /// Nguồn dữ liệu, có thể thay trong kiểm thử.
  static Stream<AccelerometerEvent> Function() source = () =>
      accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval);

  static final angle = ValueNotifier<double>(0);
  static StreamSubscription<AccelerometerEvent>? _sub;
  static int _users = 0;

  static void acquire() {
    if (_users++ > 0) return;
    try {
      _sub = source().listen(
        // Mặt đất "phía dưới" trong toạ độ máy: x = -g·sinθ, y = g·cosθ.
        (e) => angle.value = math.atan2(-e.x, e.y).clamp(-0.7, 0.7),
        onError: (Object _) {},
        cancelOnError: true,
      );
    } catch (_) {
      // Thiết bị không có cảm biến: cốc nước vẫn sóng nhẹ.
    }
  }

  static void release() {
    if (--_users > 0) return;
    _users = 0;
    _sub?.cancel();
    _sub = null;
  }
}

/// Biểu tượng động cho thói quen tốt: cốc nước sóng sánh theo độ nghiêng,
/// người chạy bộ, người đi bộ; các thói quen khác là emoji "thở" nhẹ.
class HabitIcon extends StatelessWidget {
  const HabitIcon({super.key, required this.emoji, this.done = false, this.size = 48});

  final String emoji;
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: switch (emoji) {
        '💧' => WaterGlassIcon(done: done, size: size),
        '🏃' => StickFigureIcon(running: true, done: done, size: size),
        '🚶' => StickFigureIcon(running: false, done: done, size: size),
        _ => _BreathingEmoji(emoji: emoji, done: done, size: size),
      },
    );
  }
}

mixin _Clock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  double time = 0;
  double _last = 0;
  late final Ticker _ticker = createTicker((e) {
    final t = e.inMicroseconds / 1e6;
    onTick(t, (t - _last).clamp(0.0, 0.05));
    _last = t;
    setState(() => time = t);
  });

  void onTick(double t, double dt) {}

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Cốc nước: mặt nước luôn nằm ngang theo trọng lực, sóng sánh khi lắc máy.
class WaterGlassIcon extends StatefulWidget {
  const WaterGlassIcon({super.key, required this.done, this.size = 48});

  final bool done;
  final double size;

  @override
  State<WaterGlassIcon> createState() => _WaterGlassIconState();
}

class _WaterGlassIconState extends State<WaterGlassIcon> with SingleTickerProviderStateMixin, _Clock {
  // Lò xo nối góc mặt nước với góc nghiêng thật, tạo quán tính sóng sánh.
  double _angle = 0;
  double _velocity = 0;
  late double _level = widget.done ? 0.78 : 0.38;

  @override
  void initState() {
    super.initState();
    TiltSensor.acquire();
  }

  @override
  void dispose() {
    TiltSensor.release();
    super.dispose();
  }

  @override
  void onTick(double t, double dt) {
    final target = TiltSensor.angle.value;
    final accel = (target - _angle) * 60 - _velocity * 5;
    _velocity += accel * dt;
    _angle += _velocity * dt;
    final want = widget.done ? 0.78 : 0.38;
    _level += (want - _level) * math.min(1, dt * 4);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlassPainter(
        time: time,
        angle: _angle,
        slosh: _velocity.abs().clamp(0.0, 3.0),
        level: _level,
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.time,
    required this.angle,
    required this.slosh,
    required this.level,
    required this.dark,
  });

  final double time;
  final double angle;
  final double slosh;
  final double level;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.33)),
      Paint()..color = dark ? const Color(0xFF173A4E) : const Color(0xFFE3F5FF),
    );

    // Cốc hình thang, miệng rộng hơn đáy.
    final top = h * 0.2;
    final bottom = h * 0.84;
    final glass = Path()
      ..moveTo(w * 0.26, top)
      ..lineTo(w * 0.74, top)
      ..lineTo(w * 0.67, bottom)
      ..quadraticBezierTo(w * 0.5, bottom + h * 0.03, w * 0.33, bottom)
      ..close();
    canvas.drawPath(glass, Paint()..color = Colors.white.withValues(alpha: dark ? 0.12 : 0.7));

    canvas.save();
    canvas.clipPath(glass);
    final surface = bottom - level * (bottom - top);
    canvas.translate(w / 2, surface);
    // Màn hình xoay theo máy nên mặt nước xoay ngược lại để luôn nằm ngang.
    canvas.rotate(-angle);
    final amp = h * (0.018 + 0.03 * slosh);
    final water = Path()..moveTo(-w, h);
    for (var x = -w; x <= w; x += 2) {
      water.lineTo(x, amp * math.sin(x / w * 2 * math.pi * 1.2 + time * 4));
    }
    water
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WaterColors.light, WaterColors.deep],
        ).createShader(Rect.fromLTWH(-w, -amp, w * 2, h * 0.7)),
    );
    canvas.restore();

    // Bọt khí nổi lên trong cốc.
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 3; i++) {
      final p = (time * (0.35 + i * 0.12) + i * 0.33) % 1.0;
      final y = bottom - p * (bottom - surface) - 2;
      if (y > surface + 2) canvas.drawCircle(Offset(w * (0.42 + i * 0.08), y), w * 0.022, bubble);
    }

    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, w * 0.035)
        ..strokeJoin = StrokeJoin.round
        ..color = WaterColors.mid.withValues(alpha: 0.75),
    );
    // Vệt sáng trên thành cốc.
    canvas.drawLine(
      Offset(w * 0.33, top + h * 0.08),
      Offset(w * 0.37, bottom - h * 0.12),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => true;
}

/// Người que đang chạy hoặc đi bộ, đánh tay và bước chân theo nhịp.
class StickFigureIcon extends StatefulWidget {
  const StickFigureIcon({super.key, required this.running, required this.done, this.size = 48});

  final bool running;
  final bool done;
  final double size;

  @override
  State<StickFigureIcon> createState() => _StickFigureIconState();
}

class _StickFigureIconState extends State<StickFigureIcon> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FigurePainter(
        time: time,
        running: widget.running,
        done: widget.done,
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({required this.time, required this.running, required this.done, required this.dark});

  final double time;
  final bool running;
  final bool done;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final colors = running
        ? const [Color(0xFFFFD3A8), Color(0xFFFF9F5A)]
        : const [Color(0xFFC8F0DC), Color(0xFF5CC08A)];
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.33)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark ? [colors.last.withValues(alpha: 0.35), colors.last.withValues(alpha: 0.6)] : colors,
        ).createShader(Offset.zero & size),
    );

    // Nhịp bước: chạy nhanh, đi chậm; chưa hoàn thành thì đi thong thả hơn.
    final speed = (running ? 2.2 : 1.2) * (done ? 1 : 0.6);
    final phase = time * speed * 2 * math.pi;
    final swing = running ? 0.85 : 0.45;
    final lean = running ? 0.28 : 0.06;
    final bob = (running ? 0.035 : 0.015) * h * math.cos(phase * 2).abs();

    final ink = Paint()
      ..color = dark ? Colors.white : const Color(0xFF3A2A1E)
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Vệt gió phía sau khi chạy.
    if (running) {
      final dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final x = w * (0.08 + ((time * 1.6 + i * 0.33) % 1.0) * 0.22);
        final y = h * (0.38 + i * 0.12);
        canvas.drawLine(Offset(x, y), Offset(x - w * 0.08, y), dash);
      }
    }

    final hip = Offset(w * 0.52, h * 0.58 - bob);
    final shoulder = hip + Offset(math.sin(lean) * h * 0.24, -math.cos(lean) * h * 0.24);
    canvas.drawCircle(
      shoulder + Offset(math.sin(lean) * h * 0.11, -h * 0.11),
      w * 0.085,
      ink..style = PaintingStyle.fill,
    );
    ink.style = PaintingStyle.stroke;
    canvas.drawLine(hip, shoulder, ink);

    Offset limb(Offset from, double angle, double len) =>
        from + Offset(math.sin(angle) * len, math.cos(angle) * len);

    // Hai chân: đùi lệch pha nhau, cẳng chân gập khi đưa ra sau.
    for (final k in [0.0, math.pi]) {
      final thigh = math.sin(phase + k) * swing;
      final knee = limb(hip, thigh, h * 0.15);
      final bend = math.max(0.0, -math.sin(phase + k)) * (running ? 1.3 : 0.6);
      canvas.drawLine(hip, knee, ink);
      canvas.drawLine(knee, limb(knee, thigh - bend, h * 0.15), ink);
    }
    // Hai tay đánh ngược với chân.
    for (final k in [math.pi, 0.0]) {
      final arm = math.sin(phase + k) * swing * 0.9;
      final elbow = limb(shoulder, arm, h * 0.12);
      canvas.drawLine(shoulder, elbow, ink);
      canvas.drawLine(elbow, limb(elbow, arm + (running ? 1.4 : 0.4), h * 0.1), ink);
    }

    // Mặt đất.
    canvas.drawLine(
      Offset(w * 0.18, h * 0.89),
      Offset(w * 0.82, h * 0.89),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FigurePainter old) => true;
}

class _BreathingEmoji extends StatefulWidget {
  const _BreathingEmoji({required this.emoji, required this.done, required this.size});

  final String emoji;
  final bool done;
  final double size;

  @override
  State<_BreathingEmoji> createState() => _BreathingEmojiState();
}

class _BreathingEmojiState extends State<_BreathingEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.done
            ? Colors.white.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(widget.size * 0.33),
      ),
      child: Center(
        child: ScaleTransition(
          scale: Tween(
            begin: 0.92,
            end: 1.06,
          ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOutSine)),
          child: Text(widget.emoji, style: TextStyle(fontSize: widget.size * 0.5)),
        ),
      ),
    );
  }
}
