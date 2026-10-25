import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/habit.dart';
import '../models/journal.dart';
import '../state/app_state.dart';
import '../widgets/habit_icon.dart';
import '../widgets/liquid.dart';

/// Tổng kết: mỗi ngày (biểu đồ cột), từng thói quen, cảm xúc và chuỗi "sạch".
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _range = 7;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = state.now;
    final days = [for (var i = _range - 1; i >= 0; i--) dayOffset(now, -i)];
    final goal = state.goal;
    final metDays = days.where(state.goalMetOn).length;
    final total = days.fold<int>(0, (s, d) => s + state.doneOn(d));
    final best = state.goodHabits.fold<int>(0, (m, h) => math.max(m, h.bestStreak));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Thống kê')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList.list(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 ngày')),
                    ButtonSegment(value: 30, label: Text('30 ngày')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Tile(emoji: '🎯', value: '$metDays/$_range', label: 'Ngày đạt mục tiêu'),
                    const SizedBox(width: 10),
                    _Tile(emoji: '💧', value: '$total', label: 'Lần hoàn thành'),
                    const SizedBox(width: 10),
                    _Tile(emoji: '🔥', value: '$best', label: 'Chuỗi dài nhất'),
                  ],
                ),
                _Card(
                  title: 'Mỗi ngày',
                  subtitle: 'Số thói quen hoàn thành, vạch đứt là mục tiêu ($goal)',
                  child: SizedBox(
                    height: 190,
                    child: _AnimatedChart(
                      key: ValueKey('bars$_range'),
                      builder: (t) => _BarChartPainter(
                        values: [for (final d in days) state.doneOn(d)],
                        labels: [for (final (i, d) in days.indexed) _label(d, i, _range)],
                        goal: goal,
                        maxValue: math.max(goal, state.goodHabits.length),
                        progress: t,
                        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _Card(
                  title: 'Theo thói quen',
                  subtitle: 'Tỉ lệ ngày hoàn thành trong $_range ngày qua',
                  child: Column(
                    children: [
                      for (final h in state.goodHabits) _HabitRow(habit: h, days: days, now: now),
                      if (state.goodHabits.isEmpty) const Text('Chưa có thói quen nào.'),
                    ],
                  ),
                ),
                _Card(
                  title: 'Cảm xúc',
                  subtitle: 'Cảm xúc chủ đạo mỗi ngày từ nhật ký',
                  child: days.any((d) => state.moodOn(d) != null)
                      ? SizedBox(
                          height: 170,
                          child: _AnimatedChart(
                            key: ValueKey('mood$_range'),
                            builder: (t) => _MoodChartPainter(
                              entries: [for (final d in days) state.moodOn(d)],
                              labels: [for (final (i, d) in days.indexed) _label(d, i, _range)],
                              progress: t,
                              textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : const Text('Ghi nhật ký ở mục Cảm xúc để xem biểu đồ tại đây.'),
                ),
                if (state.badHabits.isNotEmpty)
                  _Card(
                    title: 'Đang cai',
                    subtitle: 'Số ngày không tái phạm hiện tại và kỷ lục',
                    child: Column(
                      children: [for (final h in state.badHabits) _CleanRow(habit: h, state: state)],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _label(DateTime d, int i, int range) {
    if (range == 7) return ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][d.weekday - 1];
    return i % 5 == 0 || i == range - 1 ? '${d.day}/${d.month}' : '';
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.emoji, required this.value, required this.label});
  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Biểu đồ mọc lên mỗi khi hiện ra hoặc đổi khoảng thời gian.
class _AnimatedChart extends StatelessWidget {
  const _AnimatedChart({super.key, required this.builder});
  final CustomPainter Function(double t) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(size: Size.infinite, painter: builder(t)),
    );
  }
}

void _paintLabel(Canvas canvas, String text, Offset center, Color color, {double size = 11}) {
  if (text.isEmpty) return;
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, 0));
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.goal,
    required this.maxValue,
    required this.progress,
    required this.textColor,
  });

  final List<int> values;
  final List<String> labels;
  final int goal;
  final int maxValue;
  final double progress;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    final chartH = size.height - bottomPad;
    final n = values.length;
    final slot = size.width / n;
    final barW = math.min(26.0, slot * 0.62);
    final top = math.max(1, maxValue).toDouble();

    for (var i = 0; i < n; i++) {
      // Các cột mọc lên lần lượt từ trái sang phải.
      final t = Curves.easeOutBack.transform(((progress * 1.4) - i / n * 0.4).clamp(0.0, 1.0));
      final v = values[i];
      final h = math.max(3.0, chartH * (v / top) * t);
      final x = slot * i + (slot - barW) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartH - h, barW, h),
        Radius.circular(barW / 2.5),
      );
      final met = goal > 0 && v >= goal;
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: met
                ? const [WaterColors.light, WaterColors.deep]
                : [WaterColors.light.withValues(alpha: 0.45), WaterColors.mid.withValues(alpha: 0.45)],
          ).createShader(rect.outerRect),
      );
      if (n <= 7 && v > 0 && t > 0.9) {
        _paintLabel(canvas, '$v', Offset(x + barW / 2, chartH - h - 15), textColor);
      }
      _paintLabel(canvas, labels[i], Offset(x + barW / 2, chartH + 4), textColor, size: n <= 7 ? 11 : 9);
    }

    if (goal > 0) {
      final y = chartH - chartH * (goal / top);
      final paint = Paint()
        ..color = const Color(0xFF3FA66B)
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => true;
}

class _MoodChartPainter extends CustomPainter {
  _MoodChartPainter({
    required this.entries,
    required this.labels,
    required this.progress,
    required this.textColor,
  });

  final List<MoodEntry?> entries;
  final List<String> labels;
  final double progress;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    const topPad = 16.0;
    final chartH = size.height - bottomPad - topPad;
    final n = entries.length;
    final slot = size.width / n;
    Offset point(int i, MoodEntry e) =>
        Offset(slot * i + slot / 2, topPad + chartH - (e.mood.score - 1) / 4 * chartH);

    // Lưới mờ cho 5 mức cảm xúc.
    final grid = Paint()
      ..color = textColor.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var k = 0; k < 5; k++) {
      final y = topPad + chartH * k / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final pts = [
      for (var i = 0; i < n; i++)
        if (entries[i] != null) (i, point(i, entries[i]!), entries[i]!),
    ];
    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.$2.dx, pts.first.$2.dy);
      for (var k = 1; k < pts.length; k++) {
        final a = pts[k - 1].$2;
        final b = pts[k].$2;
        final mid = (a.dx + b.dx) / 2;
        path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
      }
      // Đường vẽ dần theo tiến trình hoạt ảnh.
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = const Color(0xFFFF9F43)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final (i, p, e) in pts) {
      if (i / n > progress + 0.05) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: e.mood.emoji,
          style: TextStyle(fontSize: n <= 7 ? 20 : 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    for (var i = 0; i < n; i++) {
      _paintLabel(
        canvas,
        labels[i],
        Offset(slot * i + slot / 2, size.height - bottomPad + 4),
        textColor,
        size: n <= 7 ? 11 : 9,
      );
    }
  }

  @override
  bool shouldRepaint(_MoodChartPainter old) => true;
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habit, required this.days, required this.now});
  final GoodHabit habit;
  final List<DateTime> days;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = days.where(habit.isDoneOn).length;
    final rate = days.isEmpty ? 0.0 : done / days.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          HabitIcon(emoji: habit.emoji, done: habit.isDoneOn(now), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        habit.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${(rate * 100).round()}%',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: rate),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: WaterColors.mid,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$done/${days.length} ngày · 🔥 ${habit.streak(now)} ngày liên tiếp · kỷ lục ${habit.bestStreak}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanRow extends StatelessWidget {
  const _CleanRow({required this.habit, required this.state});
  final BadHabit habit;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = habit.cleanDays(state.now);
    final best = math.max(1, habit.bestCleanDays(state.now));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(child: Text(habit.emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: current / best,
                    minHeight: 8,
                    color: const Color(0xFF5CC08A),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hiện tại $current ngày · kỷ lục ${habit.bestCleanDays(state.now)} ngày',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
