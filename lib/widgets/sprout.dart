import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mầm cây có cảm xúc: lớn dần theo [growth] (0..5), tươi hay héo theo
/// [vitality] (0..1), và luôn lắc lư nhẹ cho cảm giác "đang sống".
class SproutView extends StatefulWidget {
  const SproutView({super.key, required this.growth, required this.vitality, this.size = 220});

  final double growth;
  final double vitality;
  final double size;

  @override
  State<SproutView> createState() => _SproutViewState();
}

class _SproutViewState extends State<SproutView> with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Khi điểm thay đổi, mầm "lớn lên" mượt thay vì nhảy cóc.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.growth),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, growth, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: widget.vitality),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        builder: (context, vitality, _) => AnimatedBuilder(
          animation: _sway,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: SproutPainter(
              growth: growth.clamp(0, 5),
              vitality: vitality.clamp(0, 1),
              sway: math.sin(_sway.value * 2 * math.pi),
            ),
          ),
        ),
      ),
    );
  }
}

class SproutPainter extends CustomPainter {
  SproutPainter({required this.growth, required this.vitality, required this.sway});

  final double growth;
  final double vitality;
  final double sway;

  static const _healthyLeaf = Color(0xFF4CB86E);
  static const _wiltedLeaf = Color(0xFFB8A55A);
  static const _healthyStem = Color(0xFF3A9A5B);
  static const _wiltedStem = Color(0xFF9C8A4A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = Offset(w / 2, h * 0.74);

    _paintShadow(canvas, w, h);
    if (growth < 0.5) {
      _paintSeed(canvas, base, w);
    } else {
      _paintPlant(canvas, base, w, h);
    }
    _paintPot(canvas, w, h);
  }

  void _paintShadow(Canvas canvas, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.97), width: w * 0.5, height: h * 0.05),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
  }

  void _paintSeed(Canvas canvas, Offset base, double w) {
    // Hạt giống nhún nhảy nhẹ, chờ được chăm.
    final bob = sway * 1.5;
    final seed = Rect.fromCenter(
      center: base.translate(0, -w * 0.02 + bob),
      width: w * 0.09,
      height: w * 0.12,
    );
    canvas.save();
    canvas.translate(seed.center.dx, seed.center.dy);
    canvas.rotate(0.3 + sway * 0.05);
    canvas.translate(-seed.center.dx, -seed.center.dy);
    canvas.drawOval(seed, Paint()..color = const Color(0xFF9B6B43));
    canvas.drawOval(
      seed.deflate(seed.width * 0.28).translate(-seed.width * 0.1, -seed.height * 0.1),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.restore();
  }

  void _paintPlant(Canvas canvas, Offset base, double w, double h) {
    final leafColor = Color.lerp(_wiltedLeaf, _healthyLeaf, vitality)!;
    final stemColor = Color.lerp(_wiltedStem, _healthyStem, vitality)!;
    final droop = (1 - vitality) * 0.9;

    final stemHeight = h * (0.12 + 0.11 * growth);
    final tipLean = sway * w * 0.025 + droop * w * 0.08;
    final p0 = base;
    final p1 = base.translate(-tipLean * 0.4, -stemHeight * 0.55);
    final p2 = base.translate(tipLean, -stemHeight);

    final stem = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
    canvas.drawPath(
      stem,
      Paint()
        ..color = stemColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * (0.025 + 0.004 * growth),
    );

    Offset at(double t) {
      final u = 1 - t;
      return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
    }

    // Lá dọc thân, mọc thêm theo độ lớn, xen kẽ trái/phải.
    final leafCount = math.min(8, (growth * 1.5).floor());
    for (var i = 0; i < leafCount; i++) {
      final t = 0.3 + 0.6 * (i / math.max(1, leafCount));
      final side = i.isEven ? -1.0 : 1.0;
      final leafSize = w * (0.09 + 0.015 * growth) * (1 - t * 0.35);
      // Lá khỏe chĩa lên, lá héo rủ xuống.
      final up = 0.6 - droop * 1.1;
      final angle = (side > 0 ? -up : math.pi + up) + sway * 0.06;
      _paintLeaf(canvas, at(t), leafSize, angle, leafColor);
    }

    // Hai lá mầm trên ngọn.
    final tip = p2;
    final topSize = w * (0.1 + 0.012 * growth);
    _paintLeaf(canvas, tip, topSize, -math.pi / 2 - 0.7 - droop * 0.8 + sway * 0.08, leafColor);
    _paintLeaf(canvas, tip, topSize, -math.pi / 2 + 0.7 + droop * 0.8 + sway * 0.08, leafColor);

    if (growth >= 4.5) _paintFlower(canvas, tip.translate(0, -topSize * 0.2), w, (growth - 4.5) * 2);
  }

  void _paintLeaf(Canvas canvas, Offset origin, double length, double angle, Color color) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.5, -length * 0.42, length, 0)
      ..quadraticBezierTo(length * 0.5, length * 0.42, 0, 0)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color);
    canvas.drawLine(
      Offset.zero,
      Offset(length * 0.8, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _paintFlower(Canvas canvas, Offset center, double w, double bloom) {
    final b = bloom.clamp(0.0, 1.0);
    final r = w * 0.05 * (0.5 + 0.5 * b);
    final petal = Paint()..color = Color.lerp(const Color(0xFFFFC2D4), const Color(0xFFFF8FB1), vitality)!;
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + sway * 0.1;
      canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * r, r * 0.75, petal);
    }
    canvas.drawCircle(center, r * 0.6, Paint()..color = const Color(0xFFFFD25A));
  }

  void _paintPot(Canvas canvas, double w, double h) {
    final top = h * 0.72;
    final bottom = h * 0.96;
    final rimHalf = w * 0.22;
    final baseHalf = w * 0.16;

    final pot = Path()
      ..moveTo(w / 2 - rimHalf, top)
      ..lineTo(w / 2 + rimHalf, top)
      ..lineTo(w / 2 + baseHalf, bottom)
      ..quadraticBezierTo(w / 2, bottom + h * 0.015, w / 2 - baseHalf, bottom)
      ..close();
    canvas.drawPath(
      pot,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE8875A), Color(0xFFD16B3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTRB(w / 2 - rimHalf, top, w / 2 + rimHalf, bottom)),
    );
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(w / 2 - rimHalf - w * 0.02, top - h * 0.035, w / 2 + rimHalf + w * 0.02, top + h * 0.02),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(rim, Paint()..color = const Color(0xFFF09A6C));

    _paintFace(canvas, Offset(w / 2, top + (bottom - top) * 0.5), w);
  }

  /// Khuôn mặt trên chậu: cười khi khỏe, mếu khi héo.
  void _paintFace(Canvas canvas, Offset c, double w) {
    final eye = Paint()..color = const Color(0xFF5A2E1B);
    final eyeDx = w * 0.06;
    // Chớp mắt ngắn ở đỉnh nhịp lắc lư.
    final blink = sway > 0.97 ? 0.15 : 1.0;
    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(dx, -w * 0.015), width: w * 0.03, height: w * 0.038 * blink),
        eye,
      );
    }
    final cheek = Paint()..color = const Color(0xFFFF9E9E).withValues(alpha: 0.55 * vitality);
    canvas.drawCircle(c.translate(-eyeDx * 1.7, w * 0.012), w * 0.02, cheek);
    canvas.drawCircle(c.translate(eyeDx * 1.7, w * 0.012), w * 0.02, cheek);

    final curve = (vitality - 0.5) * w * 0.06; // dương = cười, âm = mếu
    final mouthY = c.dy + w * 0.03;
    final mouth = Path()
      ..moveTo(c.dx - w * 0.035, mouthY)
      ..quadraticBezierTo(c.dx, mouthY + curve, c.dx + w * 0.035, mouthY);
    canvas.drawPath(
      mouth,
      Paint()
        ..color = eye.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(SproutPainter old) =>
      old.growth != growth || old.vitality != vitality || old.sway != sway;
}
