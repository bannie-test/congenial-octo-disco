import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/habit.dart';
import '../services/sound_service.dart';
import '../services/weather.dart';
import '../state/app_state.dart';
import '../utils/greeting.dart';
import '../widgets/sky_scene.dart';
import '../widgets/sprout.dart';

/// Thăm Mầm: bầu trời theo giờ, thời tiết, lời chào và mục tiêu mỗi ngày.
class PlantScreen extends StatefulWidget {
  const PlantScreen({super.key});

  static Route<void> route() => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, _, _) => const PlantScreen(),
    transitionsBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.94,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );

  @override
  State<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends State<PlantScreen> {
  final _sprout = GlobalKey<SproutViewState>();
  int _line = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).refreshWeather();
    });
  }

  void _poke(AppState state) {
    HapticFeedback.lightImpact();
    state.playSound(Sfx.drop);
    _sprout.currentState?.water();
    setState(() => _line++);
  }

  Future<void> _pickCity(AppState state) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (i, c) in cities.indexed)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(c.name),
              trailing: i == state.cityIndex ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
    if (index != null) state.setCity(index);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = state.now;
    final hour = now.hour + now.minute / 60;
    final night = SkyScene.isNight(hour);
    final w = state.weather;
    final lines = plantLines(
      now: now,
      weather: w,
      vitality: state.vitality,
      done: state.doneTodayCount,
      goal: state.goal,
    );
    final ink = night ? Colors.white : const Color(0xFF16324A);
    final textTheme = Theme.of(context).textTheme;
    final shadow = [Shadow(color: Colors.black.withValues(alpha: night ? 0.4 : 0.08), blurRadius: 8)];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SkyScene(hour: hour, rainy: w?.rainy ?? false, cloudy: w != null && w.code >= 2),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_rounded, color: ink),
                    ),
                    const Spacer(),
                    ActionChip(
                      avatar: const Text('📍'),
                      label: Text(state.city.name),
                      onPressed: () => _pickCity(state),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: w == null
                      ? Text(
                          'Đang cập nhật thời tiết…',
                          style: textTheme.titleMedium?.copyWith(color: ink, shadows: shadow),
                        )
                      : _WeatherBlock(weather: w, ink: ink, shadow: shadow, night: night, today: dayKey(now)),
                ),
                const Spacer(),
                _SpeechBubble(text: lines[_line % lines.length]),
                GestureDetector(
                  onTap: () => _poke(state),
                  child: SproutView(
                    key: _sprout,
                    growth: state.stage + state.stageProgress,
                    vitality: state.vitality,
                    size: 250,
                  ),
                ),
                _GoalCard(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherBlock extends StatelessWidget {
  const _WeatherBlock({
    required this.weather,
    required this.ink,
    required this.shadow,
    required this.night,
    required this.today,
  });

  final Weather weather;
  final Color ink;
  final List<Shadow> shadow;
  final bool night;
  final String today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = weather.forecastFor(today);
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: night ? 0.15 : 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: t.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w700),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${weather.temp.round()}°',
              style: t.displayLarge?.copyWith(color: ink, fontWeight: FontWeight.w300, shadows: shadow),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weatherEmoji(weather.code, night: night)} ${weatherLabel(weather.code)}',
                    style: t.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w700, shadows: shadow),
                  ),
                  if (f != null)
                    Text(
                      'Cao ${f.max.round()}° · Thấp ${f.min.round()}°',
                      style: t.bodyMedium?.copyWith(color: ink, shadows: shadow),
                    ),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [chip('💧 Độ ẩm ${weather.humidity}%'), if (f != null) chip('☔ Mưa ${f.rain}%')],
        ),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = state.goal;
    final total = state.goodHabits.length;
    final done = state.doneTodayCount;
    final now = state.now;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '🎯 Mục tiêu mỗi ngày',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Giảm mục tiêu',
                onPressed: goal > 1 ? () => state.setDailyGoal(goal - 1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '$goal/$total',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Tăng mục tiêu',
                onPressed: goal < total ? () => state.setDailyGoal(goal + 1) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Text(
            'Hôm nay đã làm $done/$goal thói quen',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: state.todayProgress),
              duration: const Duration(milliseconds: 500),
              builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 10),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 6; i >= 0; i--) _DayGoalDot(state: state, day: dayOffset(now, -i), today: i == 0),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '🌿 Đạt mục tiêu: Mầm tươi tốt  ·  🥀 Lỡ: Mầm héo dần',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DayGoalDot extends StatelessWidget {
  const _DayGoalDot({required this.state, required this.day, required this.today});
  final AppState state;
  final DateTime day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = state.goalMetOn(day);
    final before = state.startedAt != null && day.isBefore(dayOffset(state.startedAt!, 0));
    final (bg, label) = met
        ? (const Color(0xFF5CC08A), '🌿')
        : today || before
        ? (theme.colorScheme.surfaceContainerHighest, '')
        : (const Color(0xFFE6D3B8), '🥀');
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: today ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
          ),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 4),
        Text(
          today ? 'Nay' : ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][day.weekday - 1],
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}
