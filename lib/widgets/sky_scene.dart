import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Bầu trời đổi theo giờ trong ngày: bình minh, ban ngày, hoàng hôn, đêm sao;
/// mặt trời/mặt trăng chạy theo cung, mây trôi, mưa rơi khi trời mưa.
class SkyScene extends StatefulWidget {
  const SkyScene({super.key, required this.hour, this.rainy = false, this.cloudy = false});

  /// Giờ trong ngày dạng số thực, ví dụ 18.5 = 18:30.
  final double hour;
  final bool rainy;
  final bool cloudy;

  /// Trời tối (để chọn màu chữ phía trên cho dễ đọc).
  static bool isNight(double hour) => hour >= 19 || hour < 5.5;

  @override
  State<SkyScene> createState() => _SkySceneState();
}

class _SkySceneState extends State<SkyScene> with SingleTickerProviderStateMixin {
  double _time = 0;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => setState(() => _time = e.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SkyPainter(hour: widget.hour, time: _time, rainy: widget.rainy, cloudy: widget.cloudy),
      size: Size.infinite,
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.hour, required this.time, required this.rainy, required this.cloudy});

  final double hour;
  final double time;
  final bool rainy;
  final bool cloudy;

  static const _night = [Color(0xFF0B1A33), Color(0xFF1C2F5A), Color(0xFF2E4C7E)];
  static const _dawn = [Color(0xFFFFA987), Color(0xFFFFD3A5), Color(0xFFBDE0FE)];
  static const _day = [Color(0xFF5BB8F5), Color(0xFF9FD8FF), Color(0xFFE4F5FF)];
  static const _sunset = [Color(0xFF7E57C2), Color(0xFFFF8A65), Color(0xFFFFC07A)];

  /// Các mốc giờ và bảng màu tương ứng; giữa hai mốc thì pha màu dần.
  static final _keys = <(double, List<Color>)>[
    (0, _night),
    (5, _night),
    (6.5, _dawn),
    (8.5, _day),
    (16, _day),
    (18, _sunset),
    (19.5, _night),
    (24, _night),
  ];

  List<Color> _colors() {
    for (var i = 0; i < _keys.length - 1; i++) {
      final (h0, c0) = _keys[i];
      final (h1, c1) = _keys[i + 1];
      if (hour >= h0 && hour <= h1) {
        final t = h1 == h0 ? 0.0 : (hour - h0) / (h1 - h0);
        return [for (var k = 0; k < 3; k++) Color.lerp(c0[k], c1[k], Curves.easeInOut.transform(t))!];
      }
    }
    return _night;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final colors = _colors();
    final night = SkyScene.isNight(hour);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: rainy ? colors.map((c) => Color.lerp(c, const Color(0xFF7D8A99), 0.45)!).toList() : colors,
        ).createShader(rect),
    );

    if (night) _paintStars(canvas, w, h);
    _paintSunMoon(canvas, w, h);
    _paintClouds(canvas, w, h, night);
    if (rainy) _paintRain(canvas, w, h);
    _paintHills(canvas, w, h, night);
  }

  void _paintStars(Canvas canvas, double w, double h) {
    final rnd = math.Random(5);
    for (var i = 0; i < 40; i++) {
      final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.6);
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(time * (1 + rnd.nextDouble() * 2) + i));
      canvas.drawCircle(
        p,
        0.6 + rnd.nextDouble() * 1.4,
        Paint()..color = Colors.white.withValues(alpha: twinkle),
      );
    }
  }

  void _paintSunMoon(Canvas canvas, double w, double h) {
    // Mặt trời đi từ 6h đến 18h, mặt trăng từ 18h30 đến 5h30, theo cung tròn.
    Offset arc(double t) => Offset(w * (0.08 + 0.84 * t), h * 0.5 - math.sin(math.pi * t) * h * 0.38);
    // Trời mưa thì mặt trời khuất sau mây.
    if (hour >= 6 && hour <= 18 && !rainy) {
      final c = arc((hour - 6) / 12);
      canvas.drawCircle(
        c,
        70,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFFF3B0).withValues(alpha: 0.8), const Color(0x00FFF3B0)],
          ).createShader(Rect.fromCircle(center: c, radius: 70)),
      );
      canvas.drawCircle(c, 26, Paint()..color = const Color(0xFFFFE066));
    } else if (hour >= 18.5 || hour <= 5.5) {
      final t = ((hour - 18.5 + 24) % 24) / 11;
      final c = arc(t.clamp(0.0, 1.0));
      canvas.drawCircle(c, 40, Paint()..color = Colors.white.withValues(alpha: 0.12));
      canvas.saveLayer(Rect.fromCircle(center: c, radius: 30), Paint());
      canvas.drawCircle(c, 20, Paint()..color = const Color(0xFFFFF6D6));
      canvas.drawCircle(c + const Offset(9, -6), 17, Paint()..blendMode = BlendMode.clear);
      canvas.restore();
    }
  }

  void _paintClouds(Canvas canvas, double w, double h, bool night) {
    final count = cloudy || rainy ? 5 : 3;
    final paint = Paint()..color = Colors.white.withValues(alpha: night ? 0.18 : (rainy ? 0.75 : 0.85));
    for (var i = 0; i < count; i++) {
      final speed = 8.0 + i * 4;
      final x = ((i * 157.0 + time * speed) % (w + 220)) - 110;
      final y = h * (0.12 + 0.09 * (i % 3));
      final s = 0.7 + 0.25 * (i % 2);
      for (final (dx, dy, r) in [
        (0.0, 0.0, 26.0),
        (28.0, -12.0, 30.0),
        (58.0, 0.0, 24.0),
        (30.0, 8.0, 26.0),
      ]) {
        canvas.drawCircle(Offset(x + dx * s, y + dy * s), r * s, paint);
      }
    }
  }

  void _paintRain(Canvas canvas, double w, double h) {
    final rnd = math.Random(9);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * w;
      final y = (rnd.nextDouble() * h + time * (420 + rnd.nextDouble() * 200)) % h;
      canvas.drawLine(Offset(x, y), Offset(x - 4, y + 14), paint);
    }
  }

  void _paintHills(Canvas canvas, double w, double h, bool night) {
    final back = night ? const Color(0xFF1F3B2E) : const Color(0xFF8ED39B);
    final front = night ? const Color(0xFF173025) : const Color(0xFF63BF79);
    canvas.drawOval(Rect.fromLTWH(-w * 0.3, h * 0.78, w * 0.9, h * 0.4), Paint()..color = back);
    canvas.drawOval(Rect.fromLTWH(w * 0.35, h * 0.76, w * 0.95, h * 0.42), Paint()..color = back);
    canvas.drawOval(Rect.fromLTWH(-w * 0.1, h * 0.84, w * 1.2, h * 0.4), Paint()..color = front);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
