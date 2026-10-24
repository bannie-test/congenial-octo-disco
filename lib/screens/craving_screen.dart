import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Bài thở 60 giây giúp vượt qua cơn thèm: hít 4s, giữ 4s, thở ra 6s.
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
  inhale('Hít vào', 4),
  hold('Giữ hơi', 4),
  exhale('Thở ra', 6);

  const _Phase(this.label, this.seconds);
  final String label;
  final int seconds;
}

class _CravingScreenState extends State<CravingScreen> with SingleTickerProviderStateMixin {
  static const _totalSeconds = 60;

  late final AnimationController _breath = AnimationController(vsync: this);
  late final Timer _timer;
  int _elapsed = 0;
  _Phase _phase = _Phase.inhale;

  @override
  void initState() {
    super.initState();
    _startPhase(_Phase.inhale);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed++);
      if (_elapsed >= _totalSeconds) {
        _timer.cancel();
        _breath.animateTo(0.5, duration: const Duration(seconds: 1));
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _startPhase(_Phase phase) {
    if (!mounted || _done) return;
    setState(() => _phase = phase);
    HapticFeedback.lightImpact();
    final duration = Duration(seconds: phase.seconds);
    final next = switch (phase) {
      _Phase.inhale => _Phase.hold,
      _Phase.hold => _Phase.exhale,
      _Phase.exhale => _Phase.inhale,
    };
    final TickerFuture run = switch (phase) {
      _Phase.inhale => _breath.animateTo(1, duration: duration, curve: Curves.easeInOutSine),
      _Phase.hold => _breath.animateTo(1, duration: duration),
      _Phase.exhale => _breath.animateTo(0, duration: duration, curve: Curves.easeInOutSine),
    };
    // Giữ hơi: bộ điều khiển đã ở 1 nên animateTo trả về ngay, cần chờ thủ công.
    final wait = phase == _Phase.hold ? Future<void>.delayed(duration) : run.orCancel.catchError((_) {});
    wait.then((_) => _startPhase(next));
  }

  bool get _done => _elapsed >= _totalSeconds;

  @override
  void dispose() {
    _timer.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = widget.state.now;
    final days = widget.habit.cleanDays(now);
    final saved = widget.habit.moneySaved(now);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E4D5C), Color(0xFF2E7D6B), Color(0xFF8CC9A8)],
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
                  'Cơn thèm thường qua đi sau vài phút.\nHãy thở cùng mình nhé.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, height: 1.5),
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _breath,
                    builder: (context, _) {
                      final scale = 0.55 + 0.45 * _breath.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Các vòng lan tỏa phía sau, chậm hơn vòng chính.
                          for (final k in [1.35, 1.18])
                            Container(
                              width: 240 * scale * k,
                              height: 240 * scale * k,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          Container(
                            width: 240 * scale,
                            height: 240 * scale,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFCFF3E0)]),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  blurRadius: 40 * scale,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Text(
                                _done ? 'Tuyệt vời!' : _phase.label,
                                key: ValueKey(_done ? 'done' : _phase),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFF1E4D5C),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      days > 0 || saved > 0
                          ? 'Bạn đã giữ được $days ngày${saved > 0 ? ' và tiết kiệm ${formatVnd(saved)}' : ''}. Đừng để mất nó!'
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
                      foregroundColor: const Color(0xFF1E4D5C),
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
