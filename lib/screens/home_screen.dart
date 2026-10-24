import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/habit.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/sprout.dart';
import 'add_habit_sheet.dart';
import 'craving_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Cập nhật bộ đếm "sạch" mỗi giây cho cảm giác thời gian đang trôi.
  late final Timer _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(child: _PlantCard(state: state)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: '✅',
                      label: 'Hôm nay',
                      value: '${state.doneTodayCount}/${state.goodHabits.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: '💰',
                      label: 'Đã tiết kiệm',
                      value: formatVnd(state.totalMoneySaved),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _SectionHeader(title: 'Thói quen tốt hôm nay', onAdd: () => showAddHabitSheet(context, bad: false)),
          if (state.goodHabits.isEmpty) const _EmptyHint(text: 'Thêm một thói quen nhỏ để mầm bắt đầu lớn.'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: state.goodHabits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _GoodHabitTile(habit: state.goodHabits[i], state: state),
            ),
          ),
          _SectionHeader(title: 'Đang cai', onAdd: () => showAddHabitSheet(context, bad: true)),
          if (state.badHabits.isEmpty) const _EmptyHint(text: 'Chưa có thói quen xấu nào cần bỏ. Tuyệt vời!'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList.separated(
              itemCount: state.badHabits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _BadHabitCard(habit: state.badHabits[i], state: state),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = state.vitality;
    final dark = theme.brightness == Brightness.dark;
    // Bầu trời sau lưng mầm đổi màu theo sức sống: xanh trong khi khỏe, xám khi héo.
    final sky = Color.lerp(
      dark ? const Color(0xFF2A2A2A) : const Color(0xFFE3DDD0),
      dark ? const Color(0xFF16352A) : const Color(0xFFD4F1E0),
      v,
    )!;
    final isMax = state.stage == AppState.stageThresholds.length - 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky, theme.cardTheme.color!],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mầm của bạn',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cấp ${state.stage + 1} · ${AppState.stageNames[state.stage]}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SproutView(growth: state.stage + state.stageProgress, vitality: v, size: 230),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              state.moodMessage,
              key: ValueKey(state.moodMessage),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: state.stageProgress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, p, _) => LinearProgressIndicator(value: p, minHeight: 10),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isMax
                ? 'Mầm đã nở hoa 🌸 Bạn thật tuyệt!'
                : 'Còn ${AppState.stageThresholds[state.stage + 1] - state.growthPoints} điểm nữa để lên cấp',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filledTonal(onPressed: onAdd, icon: const Icon(Icons.add), tooltip: 'Thêm'),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      sliver: SliverToBoxAdapter(
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xóa thói quen?'),
      content: Text('"$name" và toàn bộ lịch sử sẽ bị xóa.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
      ],
    ),
  );
  return ok ?? false;
}

class _GoodHabitTile extends StatelessWidget {
  const _GoodHabitTile({required this.habit, required this.state});
  final GoodHabit habit;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = habit.isDoneOn(state.now);
    final streak = habit.streak(state.now);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        final nowDone = state.toggleToday(habit);
        nowDone ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
      },
      onLongPress: () async {
        if (await _confirmDelete(context, habit.name)) state.removeGoodHabit(habit.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: done ? scheme.primaryContainer : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(habit.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onPrimaryContainer.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak > 0 ? '🔥 $streak ngày liên tiếp' : 'Chạm để hoàn thành',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                child: child,
              ),
              child: done
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey(true),
                      color: scheme.primary,
                      size: 34,
                    )
                  : Icon(
                      Icons.circle_outlined,
                      key: const ValueKey(false),
                      color: scheme.outlineVariant,
                      size: 34,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadHabitCard extends StatelessWidget {
  const _BadHabitCard({required this.habit, required this.state});
  final BadHabit habit;
  final AppState state;

  Future<void> _relapse(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bạn đã tái phạm?'),
        content: const Text(
          'Không sao cả, ai cũng có lúc vấp ngã. Thành thật ghi lại là bước đầu để làm tốt hơn. '
          'Bộ đếm sẽ bắt đầu lại từ bây giờ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không, mình vẫn ổn')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Bắt đầu lại')),
        ],
      ),
    );
    if (ok ?? false) {
      HapticFeedback.heavyImpact();
      state.relapse(habit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clean = habit.cleanFor(state.now);
    final hh = (clean.inHours % 24).toString().padLeft(2, '0');
    final mm = (clean.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (clean.inSeconds % 60).toString().padLeft(2, '0');

    return GestureDetector(
      onLongPress: () async {
        if (await _confirmDelete(context, habit.name)) state.removeBadHabit(habit.id);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(habit.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tôi đã tái phạm',
                    onPressed: () => _relapse(context),
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${clean.inDays}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'ngày  $hh:$mm:$ss',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (habit.costPerDay > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '+${formatVnd(habit.moneySaved(state.now))}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(CravingScreen.route(habit, state));
                  },
                  icon: const Text('🫁'),
                  label: const Text('Tôi đang thèm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
