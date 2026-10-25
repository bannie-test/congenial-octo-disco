import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/habit.dart';
import '../models/journal.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/liquid.dart';
import '../widgets/time_sheet.dart';

/// Lịch tháng: vòng tiến độ mục tiêu mỗi ngày, chấm sự kiện, và lịch tập
/// lặp lại hằng tuần (ví dụ thứ hai đi bộ, thứ ba đạp xe).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _selected;
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final today = dayOffset(state.now, 0);
    final selected = _selected ?? today;
    final month = _month ?? DateTime(today.year, today.month);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEventSheet(context, day: selected),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm lịch'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Lịch')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Tháng trước',
                            onPressed: () => setState(() => _month = DateTime(month.year, month.month - 1)),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'Tháng ${month.month}, ${month.year}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tháng sau',
                            onPressed: () => setState(() => _month = DateTime(month.year, month.month + 1)),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      _MonthGrid(
                        state: state,
                        month: month,
                        today: today,
                        selected: selected,
                        onSelect: (d) {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = d);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 96 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverToBoxAdapter(
              child: _DayDetail(state: state, day: selected, today: today),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.state,
    required this.month,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final AppState state;
  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final d in weekdayShort)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final n = r * 7 + c - lead + 1;
                      if (n < 1 || n > daysInMonth) return const SizedBox(height: 52);
                      final day = DateTime(month.year, month.month, n);
                      return _DayCell(
                        day: day,
                        state: state,
                        isToday: day == today,
                        isSelected: day == selected,
                        isFuture: day.isAfter(today),
                        onTap: () => onSelect(day),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.state,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime day;
  final AppState state;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = state.goal;
    final progress = goal == 0 || isFuture ? 0.0 : math.min(1.0, state.doneOn(day) / goal);
    final events = state.eventsOn(day);
    final mood = state.moodOn(day);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 36,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  track: theme.colorScheme.surfaceContainerHighest,
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primary,
                ),
                child: Center(
                  child: mood != null && !isSelected
                      ? Text(mood.mood.emoji, style: const TextStyle(fontSize: 16))
                      : Text(
                          '${day.day}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: isToday || isSelected ? FontWeight.w900 : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : isToday
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final _ in events.take(3))
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(color: Color(0xFFFF9F43), shape: BoxShape.circle),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Vòng tròn tiến độ mục tiêu quanh số ngày.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.selected,
    required this.selectedColor,
  });

  final double progress;
  final Color track;
  final bool selected;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    if (selected) canvas.drawCircle(c, r, Paint()..color = selectedColor);
    if (progress <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = progress >= 1 ? WaterColors.mid : WaterColors.light,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.selected != selected || old.track != track;
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.state, required this.day, required this.today});

  final AppState state;
  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = state.eventsOn(day);
    final done = state.goodHabits.where((h) => h.isDoneOn(day)).toList();
    final mood = state.moodOn(day);
    final title = day == today ? 'Hôm nay, ${day.day}/${day.month}' : formatDate(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Text(
            'Chưa có lịch nào. Thêm lịch tập để Mầm nhắc bạn đúng giờ, ví dụ "Đi bộ công viên" vào mỗi thứ hai.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey('event-${e.id}'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => state.removeEvent(e.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
              ),
              child: _EventTile(event: e, state: state),
            ),
          ),
        if (!day.isAfter(today)) ...[
          const SizedBox(height: 8),
          Text('Đã hoàn thành', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            done.isEmpty ? 'Chưa có thói quen nào.' : done.map((h) => '${h.emoji} ${h.name}').join('\n'),
            style: theme.textTheme.bodyMedium,
          ),
          if (mood != null) ...[
            const SizedBox(height: 12),
            Text(
              'Cảm xúc: ${mood.mood.emoji} ${mood.mood.label}${mood.note.isEmpty ? '' : ' · ${mood.note}'}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.state});
  final PlanEvent event;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habit = state.goodHabits.where((h) => h.id == event.habitId).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8D1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(event.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    '${formatHm(event.minutes)} · ${event.repeatLabel}${habit == null ? '' : ' · ${habit.emoji} ${habit.name}'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              event.remind ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
              color: event.remind ? WaterColors.mid : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

const _eventEmojis = ['🚶', '🚴', '🏃', '🏊', '🧘', '🏋️', '⚽', '🏸', '📚', '🎯'];

Future<void> showAddEventSheet(BuildContext context, {required DateTime day}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AddEventSheet(day: day),
  );
}

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet({required this.day});
  final DateTime day;

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _title = TextEditingController();
  String _emoji = _eventEmojis.first;
  String? _habitId;
  int _minutes = 18 * 60;
  bool _weekly = true;
  bool _remind = true;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final state = AppScope.of(context);
    state.addEvent(
      state.newEvent(
        title: title,
        emoji: _emoji,
        minutes: _minutes,
        habitId: _habitId,
        date: _weekly ? null : widget.day,
        weekday: _weekly ? widget.day.weekday : null,
        remind: _remind,
      ),
    );
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final weekday = weekdayNames[widget.day.weekday - 1].toLowerCase();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Thêm lịch', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _eventEmojis)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  selected: e == _emoji,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Ví dụ: Đi bộ công viên, Đạp xe 5km',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Thuộc thói quen', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Không'),
                selected: _habitId == null,
                onSelected: (_) => setState(() => _habitId = null),
              ),
              for (final h in state.goodHabits)
                ChoiceChip(
                  label: Text('${h.emoji} ${h.name}'),
                  selected: _habitId == h.id,
                  onSelected: (_) => setState(() => _habitId = h.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text('Mỗi $weekday')),
              ButtonSegment(value: false, label: Text('Chỉ ngày ${widget.day.day}/${widget.day.month}')),
            ],
            selected: {_weekly},
            onSelectionChanged: (s) => setState(() => _weekly = s.first),
          ),
          SizedBox(
            height: 160,
            child: TimeWheel(initial: _minutes, onChanged: (m) => _minutes = m),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
            title: const Text('🔔 Nhắc tôi đúng giờ'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Lưu lịch')),
        ],
      ),
    );
  }
}
