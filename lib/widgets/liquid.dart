import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// Bảng màu nước dùng chung cho mọi hiệu ứng giọt nước.
abstract final class WaterColors {
  static const light = Color(0xFF6FD0FC);
  static const mid = Color(0xFF2FA8F0);
  static const deep = Color(0xFF1477D6);
  static const ink = Color(0xFF0D3F73);
  static const glass = Color(0xFFEAF7FF);
  static const glassDark = Color(0xFF16323F);
}

enum LiquidShape { drop, circle, rounded }

/// Biểu cảm của nhân vật giọt nước.
enum DropMood { calm, happy, sleepy }

/// Giọt nước: đỉnh nhọn phía trên, thân tròn phía dưới.
Path dropPath(Size s) {
  final w = s.width;
  final h = s.height;
  final r = w / 2;
  final cy = h - r;
  return Path()
    ..moveTo(w / 2, 0)
    ..cubicTo(w / 2 + r * 0.12, h * 0.16, w, cy - r * 0.62, w, cy)
    ..arcTo(Rect.fromCircle(center: Offset(w / 2, cy), radius: r), 0, math.pi, false)
    ..cubicTo(0, cy - r * 0.62, w / 2 - r * 0.12, h * 0.16, w / 2, 0)
    ..close();
}

Path liquidContainer(LiquidShape shape, Size size, double radius) => switch (shape) {
  LiquidShape.drop => dropPath(size),
  LiquidShape.circle => Path()..addOval(Offset.zero & size),
  LiquidShape.rounded =>
    Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius))),
};

/// Vẽ nước trong một bình chứa: hai lớp sóng chạy ngược chiều, bọt khí nổi
/// lên, mặt kính phản quang và chữ tự đổi màu khi bị nước che.
class LiquidPainter extends CustomPainter {
  LiquidPainter({
    required this.shape,
    required this.level,
    required this.time,
    this.waveHeight,
    this.slosh = 0,
    this.radius = 0,
    this.bubbles = true,
    this.glass = true,
    this.glassColor = WaterColors.glass,
    this.topColor = WaterColors.light,
    this.bottomColor = WaterColors.deep,
    this.label,
    this.labelStyle,
    this.labelColor = WaterColors.deep,
    this.mood,
  });

  final LiquidShape shape;

  /// Mức nước 0..1.
  final double level;

  /// Thời gian (giây) tăng liên tục, điều khiển sóng và bọt khí.
  final double time;

  /// Biên độ sóng (px). Mặc định tỉ lệ theo chiều cao bình.
  final double? waveHeight;

  /// 0..1: sóng dâng mạnh và nghiêng qua lại khi vừa có nước đổ vào.
  final double slosh;
  final double radius;
  final bool bubbles;
  final bool glass;
  final Color glassColor;
  final Color topColor;
  final Color bottomColor;
  final String? label;
  final TextStyle? labelStyle;

  /// Màu phần chữ nằm trên mặt nước (phần chìm dưới nước luôn trắng).
  final Color labelColor;
  final DropMood? mood;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final container = liquidContainer(shape, size, radius);
    final lvl = level.clamp(0.0, 1.0);

    if (glass) {
      canvas.drawShadow(container, WaterColors.deep.withValues(alpha: 0.55), 6, true);
      canvas.drawPath(container, Paint()..color = glassColor);
    }

    final baseAmp = waveHeight ?? (h * 0.045).clamp(2.0, 8.0);
    final amp = baseAmp * (1 + 1.4 * slosh);
    // Mặt nước: lvl = 0 nằm dưới đáy, lvl = 1 phủ kín cả đỉnh sóng.
    final surface = (h + amp) - lvl * (h + 2 * amp);
    // Khi vừa đổ nước, mặt nước nghiêng qua lại như đang sóng sánh.
    final tilt = slosh * amp * 1.3 * math.sin(time * 7);

    double waveY(double x, double phase, double freq, double k) =>
        surface + amp * k * math.sin((x / w * freq + phase) * 2 * math.pi) + tilt * (x / w - 0.5) * 2;

    Path wave(double phase, double freq, double k) {
      const step = 3.0;
      final p = Path()..moveTo(0, h + amp);
      for (var x = 0.0; x <= w + step; x += step) {
        p.lineTo(x, waveY(x, phase, freq, k));
      }
      return p
        ..lineTo(w + step, h + amp)
        ..close();
    }

    final frontPhase = time / 2.3;
    final front = wave(frontPhase, 1.0, 1.0);

    canvas.save();
    canvas.clipPath(container);
    if (lvl > 0.001) {
      // Lớp sóng phía sau nhạt hơn, chạy ngược chiều để tạo chiều sâu.
      canvas.drawPath(
        wave(-time / 3.1 + 0.37, 1.35, 0.85),
        Paint()..color = topColor.withValues(alpha: 0.45),
      );
      canvas.drawPath(
        front,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, bottomColor],
          ).createShader(Rect.fromLTRB(0, math.max(0, surface - amp), w, h)),
      );

      if (bubbles && lvl > 0.06) _paintBubbles(canvas, w, h, surface + amp);

      // Vệt sáng chạy dọc đỉnh sóng.
      if (lvl < 0.985) {
        final crest = Path()..moveTo(0, waveY(0, frontPhase, 1, 1));
        for (var x = 3.0; x <= w; x += 3) {
          crest.lineTo(x, waveY(x, frontPhase, 1, 1));
        }
        canvas.drawPath(
          crest,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.45),
        );
      }
    }
    canvas.restore();

    if (glass) _paintGlass(canvas, container, w, h);
    if (label != null) _paintLabel(canvas, w, h, lvl > 0.001 ? front : null);
    if (mood != null) _paintFace(canvas, w, h);
  }

  void _paintBubbles(Canvas canvas, double w, double h, double surfaceBottom) {
    final rnd = math.Random(11);
    final paint = Paint();
    final waterHeight = h - surfaceBottom;
    for (var i = 0; i < 9; i++) {
      final speed = 0.18 + rnd.nextDouble() * 0.3;
      final offset = rnd.nextDouble();
      final x0 = w * (0.15 + rnd.nextDouble() * 0.7);
      final r = 1.0 + rnd.nextDouble() * math.max(1.0, w * 0.022);
      final t = (time * speed + offset) % 1.0;
      final y = h - t * (waterHeight + r * 2);
      if (y < surfaceBottom + r) continue;
      final x = x0 + math.sin((t * 2.5 + offset) * 2 * math.pi) * w * 0.025;
      paint.color = Colors.white.withValues(alpha: 0.15 + 0.35 * (1 - t));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _paintGlass(Canvas canvas, Path container, double w, double h) {
    canvas.drawPath(
      container,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = WaterColors.mid.withValues(alpha: 0.28),
    );
    final gloss = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, w * 0.045)
      ..color = Colors.white.withValues(alpha: 0.6);
    switch (shape) {
      case LiquidShape.drop:
        final body = Rect.fromCircle(center: Offset(w / 2, h - w / 2), radius: w / 2 - w * 0.13);
        canvas.drawArc(body, math.pi * 1.04, math.pi * 0.3, false, gloss);
        canvas.drawCircle(
          Offset(w * 0.33, h * 0.36),
          w * 0.03,
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
      case LiquidShape.circle:
        canvas.drawArc(
          Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.76, h * 0.76),
          math.pi * 1.06,
          math.pi * 0.3,
          false,
          gloss,
        );
      case LiquidShape.rounded:
        break;
    }
  }

  void _paintLabel(Canvas canvas, double w, double h, Path? water) {
    final style = labelStyle ?? TextStyle(fontSize: w * 0.22, fontWeight: FontWeight.w900);
    TextPainter layout(Color color) => TextPainter(
      text: TextSpan(
        text: label,
        style: style.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w);
    final dark = layout(labelColor);
    final center = Offset(w / 2, shape == LiquidShape.drop ? h * 0.64 : h / 2);
    final pos = center - Offset(dark.width / 2, dark.height / 2);
    dark.paint(canvas, pos);
    if (water == null) return;
    // Phần chữ chìm dưới nước chuyển sang màu trắng.
    canvas.save();
    canvas.clipPath(water);
    layout(Colors.white).paint(canvas, pos);
    canvas.restore();
  }

  void _paintFace(Canvas canvas, double w, double h) {
    final cy = shape == LiquidShape.drop ? h * 0.66 : h * 0.52;
    final eyeDx = w * 0.15;
    final ink = Paint()..color = WaterColors.ink;
    final line = Paint()
      ..color = WaterColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.032)
      ..strokeCap = StrokeCap.round;
    final blink = (time % 4.2) < 0.14;

    for (final dx in [-eyeDx, eyeDx]) {
      final c = Offset(w / 2 + dx, cy);
      final e = w * 0.05;
      switch (mood!) {
        case DropMood.happy:
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - e, c.dy + e * 0.4)
              ..quadraticBezierTo(c.dx, c.dy - e * 1.1, c.dx + e, c.dy + e * 0.4),
            line,
          );
        case DropMood.sleepy:
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - e, c.dy)
              ..quadraticBezierTo(c.dx, c.dy + e * 0.9, c.dx + e, c.dy),
            line,
          );
        case DropMood.calm:
          if (blink) {
            canvas.drawLine(c.translate(-e * 0.8, 0), c.translate(e * 0.8, 0), line);
          } else {
            canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.085, height: w * 0.11), ink);
            canvas.drawCircle(c.translate(-w * 0.014, -w * 0.024), w * 0.017, Paint()..color = Colors.white);
          }
      }
    }

    final cheek = Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.5);
    canvas.drawCircle(Offset(w / 2 - eyeDx * 1.6, cy + w * 0.07), w * 0.045, cheek);
    canvas.drawCircle(Offset(w / 2 + eyeDx * 1.6, cy + w * 0.07), w * 0.045, cheek);

    final my = cy + w * 0.08;
    if (mood == DropMood.sleepy) {
      canvas.drawCircle(Offset(w / 2, my + w * 0.01), w * 0.025, line);
      // Chữ "z" bay lên khi đang ngủ.
      for (var i = 0; i < 2; i++) {
        final t = (time * 0.45 + i * 0.5) % 1.0;
        final tp = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              fontSize: w * (0.13 + 0.06 * t),
              fontWeight: FontWeight.w800,
              color: WaterColors.ink.withValues(alpha: math.sin(t * math.pi) * 0.7),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(w * (0.7 + 0.12 * t), h * (0.3 - 0.22 * t)));
      }
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(w / 2 - w * 0.06, my)
          ..quadraticBezierTo(w / 2, my + w * (mood == DropMood.happy ? 0.09 : 0.06), w / 2 + w * 0.06, my),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(LiquidPainter old) => true;
}

/// Mixin cung cấp đồng hồ chạy liên tục cho hiệu ứng sóng.
mixin LiquidClock<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  final liquidTime = ValueNotifier<double>(0);
  Ticker? _clock;

  void startClock() {
    final clock = _clock ??= createTicker((elapsed) => liquidTime.value = elapsed.inMicroseconds / 1e6);
    if (!clock.isActive) clock.start();
  }

  void stopClock() {
    if (_clock?.isActive ?? false) _clock!.stop();
  }

  @override
  void dispose() {
    _clock?.dispose();
    liquidTime.dispose();
    super.dispose();
  }
}

/// Bình nước có sóng: mức nước dâng/hạ bằng lò xo, sóng sánh khi thay đổi
/// và nhún nhẹ kiểu "thạch". Chạm vào cũng làm nước dao động.
class LiquidDrop extends StatefulWidget {
  const LiquidDrop({
    super.key,
    required this.level,
    this.size = const Size(100, 130),
    this.shape = LiquidShape.drop,
    this.label,
    this.labelStyle,
    this.mood,
    this.glassColor,
    this.onTap,
  });

  final double level;
  final Size size;
  final LiquidShape shape;
  final String? label;
  final TextStyle? labelStyle;
  final DropMood? mood;
  final Color? glassColor;
  final VoidCallback? onTap;

  @override
  State<LiquidDrop> createState() => LiquidDropState();
}

class LiquidDropState extends State<LiquidDrop> with TickerProviderStateMixin, LiquidClock {
  static const _spring = SpringDescription(mass: 1, stiffness: 80, damping: 8);

  late final AnimationController _level = AnimationController.unbounded(vsync: this);
  late final AnimationController _slosh = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _squish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    startClock();
    // Lần đầu hiện ra, nước dâng từ đáy lên cho sinh động.
    _level.animateWith(SpringSimulation(_spring, 0, widget.level, 0));
  }

  @override
  void didUpdateWidget(LiquidDrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _level.animateWith(SpringSimulation(_spring, _level.value, widget.level, _level.velocity));
      splash();
    }
  }

  /// Làm mặt nước sóng sánh như vừa có giọt nước rơi vào.
  void splash() {
    _slosh.forward(from: 0);
    _squish.forward(from: 0);
  }

  @override
  void dispose() {
    _level.dispose();
    _slosh.dispose();
    _squish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        splash();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([liquidTime, _level, _slosh, _squish]),
        builder: (context, _) {
          final q = _squish.value;
          final wobble = q == 0 || q == 1 ? 0.0 : math.sin(q * math.pi * 3) * (1 - q) * 0.07;
          final slosh = _slosh.isAnimating ? 1 - Curves.easeOutCubic.transform(_slosh.value) : 0.0;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1 + wobble, 1 - wobble, 1),
            child: CustomPaint(
              size: widget.size,
              painter: LiquidPainter(
                shape: widget.shape,
                level: _level.value,
                time: liquidTime.value,
                slosh: slosh,
                label: widget.label,
                labelStyle: widget.labelStyle,
                labelColor: Theme.of(context).brightness == Brightness.dark
                    ? WaterColors.light
                    : WaterColors.deep,
                mood: widget.mood,
                glassColor: widget.glassColor ?? WaterColors.glass,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Nền "ly nước" cho một ô: khi [filled] chuyển sang true, nước dâng từ đáy
/// lên kèm sóng và bọt khí; khi bỏ chọn, nước rút xuống.
class WaterFill extends StatefulWidget {
  const WaterFill({
    super.key,
    required this.filled,
    required this.child,
    this.radius = 22,
    this.topColor = const Color(0xFFCDEFFF),
    this.bottomColor = const Color(0xFFA9E0FF),
  });

  final bool filled;
  final Widget child;
  final double radius;
  final Color topColor;
  final Color bottomColor;

  @override
  State<WaterFill> createState() => _WaterFillState();
}

class _WaterFillState extends State<WaterFill> with TickerProviderStateMixin, LiquidClock {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: widget.filled ? 1 : 0,
  );

  @override
  void didUpdateWidget(WaterFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filled == widget.filled) return;
    startClock();
    _fill
        .animateTo(widget.filled ? 1 : 0, curve: widget.filled ? Curves.easeOutCubic : Curves.easeInCubic)
        .whenCompleteOrCancel(() {
          if (mounted && !_fill.isAnimating) stopClock();
        });
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fill, liquidTime]),
      builder: (context, child) {
        final lvl = _fill.value;
        return CustomPaint(
          painter: LiquidPainter(
            shape: LiquidShape.rounded,
            radius: widget.radius,
            level: lvl,
            time: liquidTime.value,
            // Sóng mạnh nhất lúc đang dâng, phẳng lặng khi đã đầy hoặc cạn.
            waveHeight: 7 * math.sin(math.pi * lvl),
            bubbles: _fill.isAnimating,
            glass: false,
            topColor: widget.topColor,
            bottomColor: widget.bottomColor,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
