import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit.dart';
import '../state/app_state.dart';
import '../widgets/liquid.dart';

/// Bài thở 60 giây giúp vượt qua cơn thèm: hít 4s, giữ 4s, thở ra 6s.
/// Nước trong bình dâng lên khi hít vào và rút xuống khi thở ra.
class CravingScreen extends StatefulWidget {
  const CravingScreen({super.key, required this.habit, required this.state});

  final BadHabit habit;
  final AppState state;

  static Route<void> route(BadHabit habit, AppState state) => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, _, _) => CravingScreen(habit: habit, state: state),
    transitionsBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(
          begin: 1.08,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );

  @override
  State<CravingScreen> createState() => _CravingScreenState();
}

enum _Phase {
  inhale('Hít vào'),
  hold('Giữ hơi'),
  exhale('Thở ra');

  const _Phase(this.label);
  final String label;
}

class _CravingScreenState extends State<CravingScreen> with TickerProviderStateMixin, LiquidClock {
  static const _totalSeconds = 60;
  static const _cycleSeconds = 14;

  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _cycleSeconds),
  );
  late final Timer _timer;
  int _elapsed = 0;
  _Phase _phase = _Phase.inhale;
  double _frozen = 0;

  bool get _done => _elapsed >= _totalSeconds;

  double get _seconds => _cycle.value * _cycleSeconds;

  _Phase get _currentPhase => switch (_seconds) {
    < 4 => _Phase.inhale,
    < 8 => _Phase.hold,
    _ => _Phase.exhale,
  };

  /// Độ "đầy hơi" 0..1 theo nhịp thở.
  double get _breath {
    final s = _seconds;
    if (s < 4) return Curves.easeInOutSine.transform(s / 4);
    if (s < 8) return 1;
    return 1 - Curves.easeInOutSine.transform((s - 8) / 6);
  }

  @override
  void initState() {
    super.initState();
    startClock();
    HapticFeedback.lightImpact();
    _cycle
      ..addListener(() {
        final p = _currentPhase;
        if (p != _phase && !_done) {
          HapticFeedback.lightImpact();
          setState(() => _phase = p);
        }
      })
      ..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed++);
      if (_done) {
        _timer.cancel();
        _frozen = _breath;
        _cycle.stop();
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = widget.state.now;
    final days = widget.habit.cleanDays(now);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F3550), Color(0xFF1B6A8A), Color(0xFF7CC8D8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Cơn thèm thường qua đi sau vài phút.\nHãy thở cùng Mầm nhé.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, height: 1.5),
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_cycle, liquidTime]),
                    builder: (context, _) {
                      final b = _done ? _frozen : _breath;
                      final scale = 0.86 + 0.14 * b;
                      final time = liquidTime.value;
                      return SizedBox.square(
                        dimension: 330,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RingsPainter(time: time, radius: 120 * scale),
                              ),
                            ),
                            Transform.scale(
                              scale: scale,
                              child: CustomPaint(
                                size: const Size.square(240),
                                painter: LiquidPainter(
                                  shape: LiquidShape.circle,
                                  level: 0.18 + 0.64 * b,
                                  time: time,
                                  glassColor: Colors.white.withValues(alpha: 0.92),
                                  label: _done ? 'Tuyệt vời!' : _phase.label,
                                  labelStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      _done ? 'Bạn đã vượt qua cơn thèm 💪' : 'Còn ${_totalSeconds - _elapsed} giây',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days > 0
                          ? 'Bạn đã giữ được $days ngày. Đừng để mất nó!'
                          : 'Mỗi lần vượt qua cơn thèm, bạn mạnh mẽ hơn một chút.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _done ? 1 : 0,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F3550),
                    ),
                    onPressed: _done ? () => Navigator.pop(context) : null,
                    child: const Text('Mình ổn rồi'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Các vòng gợn sóng lan ra từ bình nước.
class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.time, required this.radius});

  final double time;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var k = 0; k < 3; k++) {
      final r = (time * 0.28 + k / 3) % 1.0;
      canvas.drawCircle(
        c,
        radius * (1.02 + 0.32 * r),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 4 * (1 - r)
          ..color = Colors.white.withValues(alpha: math.max(0, (1 - r) * 0.28)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.time != time || old.radius != radius;
}
