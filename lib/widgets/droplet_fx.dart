import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'liquid.dart';

/// Thả một giọt nước bay theo đường cong từ [from] tới [to] (toạ độ màn hình),
/// rơi xuống tạo gợn sóng và bắn bọt nước. [onLand] được gọi lúc chạm đích.
void launchDroplet(BuildContext context, {required Offset from, required Offset to, VoidCallback? onLand}) {
  _insert(context, (onDone) => _DropletFlight(from: from, to: to, onLand: onLand, onDone: onDone));
}

/// Một chùm giọt nước bung ra từ [center], dùng khi ăn mừng.
void launchDropletBurst(BuildContext context, Offset center) {
  _insert(context, (onDone) => _DropletBurst(center: center, onDone: onDone));
}

void _insert(BuildContext context, Widget Function(VoidCallback onDone) build) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(child: IgnorePointer(child: build(() => entry.remove()))),
  );
  overlay.insert(entry);
}

/// Vẽ một giọt nước nhỏ có tâm thân tròn tại [at], đầu nhọn quay ngược hướng [direction].
void paintDroplet(
  Canvas canvas,
  Offset at,
  double width, {
  double direction = math.pi / 2,
  double opacity = 1,
}) {
  final size = Size(width, width * 1.3);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(direction - math.pi / 2);
  canvas.translate(-size.width / 2, -size.height + size.width / 2);
  final path = dropPath(size);
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          WaterColors.light.withValues(alpha: opacity),
          WaterColors.deep.withValues(alpha: opacity),
        ],
      ).createShader(Offset.zero & size),
  );
  canvas.drawCircle(
    Offset(size.width * 0.36, size.height * 0.58),
    size.width * 0.12,
    Paint()..color = Colors.white.withValues(alpha: 0.75 * opacity),
  );
  canvas.restore();
}

class _DropletFlight extends StatefulWidget {
  const _DropletFlight({required this.from, required this.to, required this.onDone, this.onLand});

  final Offset from;
  final Offset to;
  final VoidCallback onDone;
  final VoidCallback? onLand;

  @override
  State<_DropletFlight> createState() => _DropletFlightState();
}

class _DropletFlightState extends State<_DropletFlight> with SingleTickerProviderStateMixin {
  static const landAt = 0.55;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _c
      ..addListener(() {
        if (!_landed && _c.value >= landAt) {
          _landed = true;
          widget.onLand?.call();
        }
      })
      ..forward().then((_) {
        if (mounted) widget.onDone();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _FlightPainter(t: _c.value, from: widget.from, to: widget.to),
      ),
    );
  }
}

class _FlightPainter extends CustomPainter {
  _FlightPainter({required this.t, required this.from, required this.to})
    : control = Offset(
        from.dx + (to.dx - from.dx) * 0.2 + (to.dx >= from.dx ? -40 : 40),
        math.max(40, math.min(from.dy, to.dy) - 110),
      );

  final double t;
  final Offset from;
  final Offset to;
  final Offset control;

  Offset _at(double e) {
    final u = 1 - e;
    return from * (u * u) + control * (2 * u * e) + to * (e * e);
  }

  Offset _velocity(double e) => (control - from) * (2 * (1 - e)) + (to - control) * (2 * e);

  @override
  void paint(Canvas canvas, Size size) {
    const landAt = _DropletFlightState.landAt;
    if (t < landAt) {
      final f = t / landAt;
      // Bay lên chậm rồi tăng tốc khi rơi, như có trọng lực.
      final e = Curves.easeInSine.transform(f);
      // Vệt đuôi lấp lánh phía sau.
      for (var k = 1; k <= 4; k++) {
        final ek = Curves.easeInSine.transform((f - k * 0.04).clamp(0.0, 1.0));
        canvas.drawCircle(
          _at(ek),
          math.max(0.8, 3.4 - k * 0.6),
          Paint()..color = WaterColors.light.withValues(alpha: 0.42 - k * 0.08),
        );
      }
      final v = _velocity(e);
      paintDroplet(
        canvas,
        _at(e),
        15 * (1 + 0.25 * math.sin(math.pi * f)),
        direction: math.atan2(v.dy, v.dx),
      );
      return;
    }

    final s = ((t - landAt) / (1 - landAt)).clamp(0.0, 1.0);
    // Gợn sóng lan ra quanh điểm rơi.
    for (var k = 0; k < 3; k++) {
      final sk = (s - k * 0.16).clamp(0.0, 1.0);
      if (sk <= 0) continue;
      final rx = 6 + 36 * Curves.easeOutCubic.transform(sk);
      canvas.drawOval(
        Rect.fromCenter(center: to, width: rx * 2, height: rx * 0.7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = WaterColors.mid.withValues(alpha: (1 - sk) * 0.6),
      );
    }
    // Bọt nước bắn lên theo hình quạt rồi rơi xuống.
    for (var i = 0; i < 7; i++) {
      final a = -math.pi / 2 + (i - 3) * 0.34;
      final speed = 34.0 + (i % 3) * 14;
      final pos = to + Offset(math.cos(a) * speed * s, math.sin(a) * speed * s + 80 * s * s);
      canvas.drawCircle(pos, 3.2 * (1 - s * 0.6), Paint()..color = WaterColors.mid.withValues(alpha: 1 - s));
    }
  }

  @override
  bool shouldRepaint(_FlightPainter old) => old.t != t;
}

class _DropletBurst extends StatefulWidget {
  const _DropletBurst({required this.center, required this.onDone});

  final Offset center;
  final VoidCallback onDone;

  @override
  State<_DropletBurst> createState() => _DropletBurstState();
}

class _DropletBurstState extends State<_DropletBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(painter: _BurstPainter(_c.value, widget.center)),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.center);

  final double t;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    final s = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 20; i++) {
      final angle = i / 20 * 2 * math.pi + rnd.nextDouble() * 0.3;
      final speed = 70 + rnd.nextDouble() * 90;
      final dir = Offset(math.cos(angle), math.sin(angle) - 0.6);
      final pos = center + dir * speed * s + Offset(0, 160 * t * t);
      final vel = dir * speed + Offset(0, 320 * t);
      paintDroplet(
        canvas,
        pos,
        (7 + rnd.nextDouble() * 6) * (1 - t * 0.4),
        direction: math.atan2(vel.dy, vel.dx),
        opacity: (1 - t).clamp(0.0, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
