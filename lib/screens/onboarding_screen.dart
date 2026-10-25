import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/habit.dart';
import '../widgets/drop_buddy.dart';
import '../widgets/liquid.dart';
import '../widgets/sprout.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  // Uống nước là thói quen mặc định, luôn được chọn.
  final _good = <HabitTemplate>{waterTemplate};
  final _bad = <HabitTemplate>{};
  bool _morning = true;
  bool _evening = true;
  bool? _water;
  bool _busy = false;

  static const _pageCount = 4;

  /// Mặc định bật nhắc uống nước nếu người dùng chọn thói quen uống nước.
  bool get _waterOn => _water ?? true;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    _pages.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  Future<void> _finish({required bool enable}) async {
    final state = AppScope.of(context);
    state.reminders
      ..morning = _morning
      ..evening = _evening;
    if (enable) {
      setState(() => _busy = true);
      // Chỉ xin quyền khi người dùng chủ động bấm, sau khi đã hiểu lợi ích.
      state.notificationsAllowed = await state.notifications.requestPermission();
      if (!mounted) return;
    }
    HapticFeedback.mediumImpact();
    state.completeOnboarding(
      good: _good.toList(),
      bad: _bad.toList(),
      enableReminders: enable,
      waterReminder: _waterOn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = switch (_page) {
      1 => _good.isNotEmpty,
      _ => true,
    };
    final label = switch (_page) {
      0 => 'Bắt đầu',
      2 => _bad.isEmpty ? 'Bỏ qua' : 'Tiếp tục',
      _ => 'Tiếp tục',
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _Dots(count: _pageCount, active: _page),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  const _WelcomePage(),
                  _PickPage(
                    title: 'Bạn muốn xây thói quen nào?',
                    subtitle: 'Mỗi lần hoàn thành, mầm của bạn sẽ lớn thêm một chút.',
                    templates: goodHabitTemplates,
                    selected: _good,
                    onToggle: (t) {
                      if (t == waterTemplate) return;
                      setState(() => _good.contains(t) ? _good.remove(t) : _good.add(t));
                    },
                  ),
                  _PickPage(
                    title: 'Và muốn bỏ điều gì?',
                    subtitle: 'Mỗi ngày không tái phạm, mầm khỏe hơn và bạn tiết kiệm được tiền.',
                    templates: badHabitTemplates,
                    selected: _bad,
                    onToggle: (t) => setState(() => _bad.contains(t) ? _bad.remove(t) : _bad.add(t)),
                  ),
                  _ReminderPage(
                    morning: _morning,
                    evening: _evening,
                    water: _waterOn,
                    onMorning: (v) => setState(() => _morning = v),
                    onEvening: (v) => setState(() => _evening = v),
                    onWater: (v) => setState(() => _water = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _page == _pageCount - 1
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: _busy ? null : () => _finish(enable: true),
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : const Text('Bật nhắc nhở 🔔'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _finish(enable: false),
                          child: const Text('Để sau'),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: canContinue ? 1 : 0.4,
                        child: FilledButton(
                          onPressed: canContinue ? _next : null,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(label, key: ValueKey(label)),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= active ? color : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ở màn chào, mầm tự lớn từ hạt đến ra hoa để "khoe" trước hành trình.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 5),
            duration: const Duration(seconds: 4),
            curve: Curves.easeInOutCubic,
            builder: (context, g, _) => SproutView(growth: g, vitality: 1, size: 260),
          ),
          const SizedBox(height: 24),
          Text(
            'Chào bạn, mình là Mầm 🌱',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Chăm thói quen tốt, mình sẽ lớn.\nTái phạm thói quen xấu, mình sẽ héo.\nCùng nhau lớn lên nhé!',
            style: text.bodyLarge?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PickPage extends StatelessWidget {
  const _PickPage({
    required this.title,
    required this.subtitle,
    required this.templates,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final List<HabitTemplate> templates;
  final Set<HabitTemplate> selected;
  final ValueChanged<HabitTemplate> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in templates)
              AnimatedScale(
                scale: selected.contains(t) ? 1.05 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: FilterChip(
                  label: Text('${t.emoji}  ${t.name}${t == waterTemplate ? ' · mặc định' : ''}'),
                  labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  selected: selected.contains(t),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onToggle(t);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReminderPage extends StatelessWidget {
  const _ReminderPage({
    required this.morning,
    required this.evening,
    required this.water,
    required this.onMorning,
    required this.onEvening,
    required this.onWater,
  });

  final bool morning;
  final bool evening;
  final bool water;
  final ValueChanged<bool> onMorning;
  final ValueChanged<bool> onEvening;
  final ValueChanged<bool> onWater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget option(String emoji, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        const Center(child: DropBuddy(size: 92, mood: DropMood.happy, bell: true)),
        const SizedBox(height: 4),
        Text(
          'Để Mầm nhắc bạn nhé',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Mầm chỉ nhắc nhẹ nhàng, đúng lúc. Bạn có thể đổi giờ bất cứ lúc nào.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              option('☀️', 'Chào buổi sáng', '08:00 mỗi ngày', morning, onMorning),
              const Divider(height: 1, indent: 56),
              option('💧', 'Nhắc uống nước', '2 giờ một lần, từ 8:00 đến 20:00', water, onWater),
              const Divider(height: 1, indent: 56),
              option('🌙', 'Tổng kết cuối ngày', '21:00 mỗi ngày', evening, onEvening),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Thói quen bạn chọn cũng đã có sẵn giờ nhắc gợi ý.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
