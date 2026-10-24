import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'liquid.dart';

/// "Giọt": nhân vật giọt nước nhấp nhô trên mặt nước, gợn sóng lan ra mỗi
/// khi chạm xuống. Có thể kèm chiếc chuông nhỏ lắc lư cho màn nhắc nhở.
class DropBuddy extends StatefulWidget {
  const DropBuddy({
    super.key,
    this.size = 120,
    this.mood = DropMood.calm,
    this.level = 0.6,
    this.bell = false,
  });

  /// Chiều rộng của giọt nước.
  final double size;
  final DropMood mood;
  final double level;
  final bool bell;

  @override
  State<DropBuddy> createState() => _DropBuddyState();
}

class _DropBuddyState extends State<DropBuddy> with TickerProviderStateMixin, LiquidClock {
  @override
  void initState() {
    super.initState();
    startClock();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final dropSize = Size(w, w * 1.3);
    final boxW = w * 1.7;
    final boxH = dropSize.height + w * 0.42;
    final glass = Theme.of(context).brightness == Brightness.dark ? WaterColors.glassDark : WaterColors.glass;

    return SizedBox(
      width: boxW,
      height: boxH,
      child: ValueListenableBuilder<double>(
        valueListenable: liquidTime,
        builder: (context, time, _) {
          // Ngủ thì thở chậm, bình thường thì nhún nhảy.
          final speed = widget.mood == DropMood.sleepy ? 1.2 : 2.4;
          final bob = math.sin(time * speed);
          final lift = (bob + 1) / 2 * w * 0.1;
          // Hơi bẹt ra khi chạm mặt nước.
          final squash = math.max(0, -bob) * 0.06;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RipplePainter(time: time, center: Offset(boxW / 2, boxH - w * 0.16), width: w),
                ),
              ),
              Positioned(
                left: (boxW - w) / 2,
                bottom: w * 0.12 + lift,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(1 + squash, 1 - squash, 1),
                  child: CustomPaint(
                    size: dropSize,
                    painter: LiquidPainter(
                      shape: LiquidShape.drop,
                      level: widget.level,
                      time: time,
                      mood: widget.mood,
                      glassColor: glass,
                    ),
                  ),
                ),
              ),
              if (widget.bell)
                Positioned(
                  right: boxW * 0.06,
                  top: w * 0.02 + lift * 0.5,
                  child: _Bell(time: time, size: w * 0.36),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.time, required this.size});

  final double time;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Cứ 3 giây chuông rung một hồi ngắn.
    final t = time % 3.0;
    final angle = t < 0.9 ? math.sin(t * math.pi * 7) * (1 - t / 0.9) * 0.5 : 0.0;
    return Transform.rotate(
      angle: angle,
      alignment: Alignment.topCenter,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: WaterColors.deep.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text('🔔', style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.time, required this.center, required this.width});

  final double time;
  final Offset center;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width * 1.1, height: width * 0.22),
      Paint()..color = WaterColors.mid.withValues(alpha: 0.12),
    );
    for (var k = 0; k < 3; k++) {
      final r = (time * 0.38 + k / 3) % 1.0;
      final rw = width * (0.45 + 1.1 * r);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: rw, height: rw * 0.24),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = WaterColors.mid.withValues(alpha: (1 - r) * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.time != time;
}
