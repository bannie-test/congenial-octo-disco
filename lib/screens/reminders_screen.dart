import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/habit.dart';
import '../models/reminder.dart';
import '../services/reminder_planner.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/drop_buddy.dart';
import '../widgets/droplet_fx.dart';
import '../widgets/liquid.dart';
import '../widgets/time_sheet.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const RemindersScreen());

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final r = state.reminders;
    final active = r.enabled;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Nhắc nhở')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _HeaderCard(state: state)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList.list(
              children: [
                _Group(
                  children: [
                    _SwitchRow(
                      emoji: '🔔',
                      title: 'Bật nhắc nhở',
                      subtitle: active ? 'Mầm sẽ nhắc bạn đúng giờ' : 'Tất cả lời nhắc đang tắt',
                      value: active,
                      onChanged: (v) async {
                        if (v) {
                          await state.enableReminders();
                        } else {
                          state.updateReminders((r) => r.enabled = false);
                        }
                      },
                    ),
                  ],
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: active ? 1 : 0.45,
                  child: IgnorePointer(
                    ignoring: !active,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('Mỗi ngày'),
                        _Group(
                          children: [
                            _TimedRow(
                              emoji: '☀️',
                              title: 'Chào buổi sáng',
                              subtitle: 'Lời chúc mở đầu ngày mới',
                              minutes: r.morningAt,
                              value: r.morning,
                              onChanged: (v) => state.updateReminders((r) => r.morning = v),
                              onPick: (m) => state.updateReminders((r) => r.morningAt = m),
                            ),
                            const _RowDivider(),
                            _TimedRow(
                              emoji: '🌙',
                              title: 'Tổng kết cuối ngày',
                              subtitle: 'Hỏi thăm xem bạn đã tưới Mầm đủ chưa',
                              minutes: r.eveningAt,
                              value: r.evening,
                              onChanged: (v) => state.updateReminders((r) => r.evening = v),
                              onPick: (m) => state.updateReminders((r) => r.eveningAt = m),
                            ),
                          ],
                        ),
                        const _SectionTitle('Uống nước'),
                        _WaterCard(state: state),
                        if (state.goodHabits.isNotEmpty) ...[
                          const _SectionTitle('Thói quen tốt'),
                          _Group(
                            children: [
                              for (final (i, h) in state.goodHabits.indexed) ...[
                                if (i > 0) const _RowDivider(),
                                _HabitRow(
                                  emoji: h.emoji,
                                  name: h.name,
                                  reminder: h.reminder,
                                  suggested: _suggestedTime(h.name, goodHabitTemplates, 20 * 60),
                                  onChanged: (rem) => state.setGoodReminder(h, rem),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (state.badHabits.isNotEmpty) ...[
                          const _SectionTitle('Giờ hay thèm'),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 10, right: 4),
                            child: Text(
                              'Mầm sẽ nhắc đúng lúc bạn hay thèm, kèm một mẹo nhỏ để vượt qua.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                          _Group(
                            children: [
                              for (final (i, h) in state.badHabits.indexed) ...[
                                if (i > 0) const _RowDivider(),
                                _HabitRow(
                                  emoji: h.emoji,
                                  name: h.name,
                                  reminder: h.reminder,
                                  suggested: _suggestedTime(h.name, badHabitTemplates, 15 * 60),
                                  hint: 'Chọn khung giờ bạn hay thèm nhất trong ngày.',
                                  onChanged: (rem) => state.setBadReminder(h, rem),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const _SectionTitle('Thành tích'),
                        _Group(
                          children: [
                            _SwitchRow(
                              emoji: '🏆',
                              title: 'Báo khi đạt cột mốc',
                              subtitle: '1, 3, 7, 14, 30… ngày không tái phạm',
                              value: r.milestones,
                              onChanged: (v) => state.updateReminders((r) => r.milestones = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: () => _sendTest(context, state),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Gửi thử một thông báo'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _suggestedTime(String name, List<HabitTemplate> templates, int fallback) =>
      templates.where((t) => t.name == name).firstOrNull?.remindAt ?? fallback;

  Future<void> _sendTest(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.mediumImpact();
    await state.notifications.showNow(
      title: '💧 Mầm gửi lời chào!',
      body: 'Thông báo đã hoạt động. Mầm sẽ nhắc bạn đúng giờ nhé.',
    );
    messenger.showSnackBar(const SnackBar(content: Text('Đã gửi! Kéo thanh thông báo xuống để xem nhé.')));
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final r = state.reminders;
    final plan = state.plannedNotifications;
    final todayCount = notificationsOn(plan, state.now).length;
    final next = nextNotification(plan, state.now);
    final blocked = r.enabled && state.notificationsAllowed == false;

    final (mood, title, subtitle) = !r.enabled
        ? (DropMood.sleepy, 'Mầm đang ngủ quên', 'Bật nhắc nhở để Mầm nhắc bạn uống nước và giữ thói quen.')
        : blocked
        ? (DropMood.calm, 'Thông báo đang bị chặn', 'Hãy cho phép Mầm gửi thông báo trong Cài đặt của máy.')
        : (
            DropMood.happy,
            'Hôm nay Mầm nhắc bạn $todayCount lần',
            next == null ? 'Chưa có lời nhắc nào được bật.' : 'Lần tới: ${describeNext(next, state.now)}',
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF15303F), Color(0xFF1A2830)]
              : const [Color(0xFFDDF3FF), Color(0xFFF3FBFF)],
        ),
      ),
      child: Row(
        children: [
          DropBuddy(size: 70, mood: mood, bell: r.enabled && !blocked),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (!r.enabled || blocked) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () async {
                      if (!r.enabled) {
                        await state.enableReminders();
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      final opened = await state.notifications.openSettings();
                      if (!opened) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Vào Cài đặt › Thông báo › Mầm và bật "Cho phép thông báo".'),
                          ),
                        );
                      }
                    },
                    child: Text(!r.enabled ? 'Bật nhắc nhở' : 'Mở Cài đặt'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 64, endIndent: 16);
}

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            SizedBox(width: 36, child: Text(emoji, style: const TextStyle(fontSize: 24))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// Ô hiện giờ dạng viên thuốc, chạm để đổi giờ.
class _TimePill extends StatelessWidget {
  const _TimePill({required this.minutes, required this.onTap, this.enabled = true});

  final int minutes;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: enabled
          ? (dark ? const Color(0xFF173A4E) : const Color(0xFFE1F4FF))
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            formatHm(minutes),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: enabled ? (dark ? WaterColors.light : WaterColors.deep) : theme.colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimedRow extends StatelessWidget {
  const _TimedRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.value,
    required this.onChanged,
    required this.onPick,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final int minutes;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int> onPick;

  Future<void> _pick(BuildContext context) async {
    final m = await showTimeSheet(context, initial: minutes, title: title);
    if (m != null) onPick(m);
  }

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
      onTap: () => _pick(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TimePill(minutes: minutes, enabled: value, onTap: () => _pick(context)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.emoji,
    required this.name,
    required this.reminder,
    required this.suggested,
    required this.onChanged,
    this.hint,
  });

  final String emoji;
  final String name;
  final HabitReminder? reminder;
  final int suggested;
  final String? hint;
  final ValueChanged<HabitReminder?> onChanged;

  Future<void> _edit(BuildContext context) async {
    final result = await showHabitReminderSheet(
      context,
      emoji: emoji,
      name: name,
      initial: reminder,
      suggestedMinutes: suggested,
      hint: hint,
    );
    if (result != null) onChanged(result.reminder);
  }

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final on = r?.enabled ?? false;
    return _RowShell(
      emoji: emoji,
      title: name,
      subtitle: r == null ? 'Chưa đặt giờ nhắc' : (on ? r.label : 'Đang tắt · ${r.label}'),
      onTap: () => _edit(context),
      trailing: Switch(
        value: on,
        onChanged: (v) {
          if (r == null) {
            _edit(context);
          } else {
            onChanged(HabitReminder(minutes: r.minutes, weekdays: {...r.weekdays}, enabled: v));
          }
        },
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.state});
  final AppState state;

  static String _interval(int m) => switch (m) {
    < 60 => '$m phút',
    90 => '1,5 giờ',
    _ => '${m ~/ 60} giờ',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = state.reminders;
    final slots = r.waterSlots;

    Future<void> pick({required bool from}) async {
      final m = await showTimeSheet(
        context,
        initial: from ? r.waterFrom : r.waterTo,
        title: from ? 'Bắt đầu nhắc từ' : 'Nhắc đến',
      );
      if (m == null) return;
      state.updateReminders((r) {
        if (from) {
          r.waterFrom = m;
          r.waterTo = math.max(r.waterTo, m);
        } else {
          r.waterTo = m;
          r.waterFrom = math.min(r.waterFrom, m);
        }
      });
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(
            emoji: '💧',
            title: 'Nhắc uống nước',
            subtitle: r.water
                ? '${slots.length} lần mỗi ngày · ${_interval(r.waterEvery)} một lần'
                : 'Đang tắt',
            value: r.water,
            onChanged: (v) => state.updateReminders((r) => r.water = v),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !r.water
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in ReminderSettings.waterIntervals)
                              ChoiceChip(
                                label: Text(_interval(m)),
                                selected: r.waterEvery == m,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  state.updateReminders((r) => r.waterEvery = m);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text('Từ', style: theme.textTheme.bodyMedium),
                            const SizedBox(width: 8),
                            _TimePill(minutes: r.waterFrom, onTap: () => pick(from: true)),
                            const SizedBox(width: 12),
                            Text('đến', style: theme.textTheme.bodyMedium),
                            const SizedBox(width: 8),
                            _TimePill(minutes: r.waterTo, onTap: () => pick(from: false)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        WaterTimeline(slots: slots, now: state.now),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dòng thời gian 5h–24h với các giọt nước đánh dấu giờ nhắc uống nước.
class WaterTimeline extends StatelessWidget {
  const WaterTimeline({super.key, required this.slots, required this.now});

  final List<int> slots;
  final DateTime now;

  static const _start = 5 * 60;
  static const _end = 24 * 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nowMin = now.hour * 60 + now.minute;
    final dark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 62,
      child: LayoutBuilder(
        builder: (context, c) {
          double x(int m) => (m - _start) / (_end - _start) * c.maxWidth;
          final progress = x(nowMin.clamp(_start, _end));
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 30,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark ? WaterColors.glassDark : WaterColors.glass,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                width: progress,
                top: 30,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [WaterColors.light, WaterColors.mid]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              for (final (i, m) in slots.indexed)
                Positioned(
                  key: ValueKey(m),
                  left: x(m) - 7,
                  top: 6,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 350 + i * 45),
                    curve: Interval(i * 45 / (350 + i * 45), 1, curve: Curves.easeOutBack),
                    builder: (context, v, child) => Transform.scale(
                      scale: v,
                      alignment: Alignment.bottomCenter,
                      child: Opacity(opacity: m <= nowMin ? 0.45 : 1, child: child),
                    ),
                    child: const CustomPaint(size: Size(14, 18), painter: _MiniDropPainter()),
                  ),
                ),
              for (final h in [6, 12, 18, 24])
                Positioned(
                  left: x(h * 60) - 14,
                  width: 28,
                  top: 42,
                  child: Text(
                    '${h}h',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniDropPainter extends CustomPainter {
  const _MiniDropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    paintDroplet(canvas, Offset(size.width / 2, size.height - size.width / 2), size.width);
  }

  @override
  bool shouldRepaint(_MiniDropPainter old) => false;
}
