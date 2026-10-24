import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reminder.dart';
import '../utils/format.dart';
import 'liquid.dart';

/// Bánh xe chọn giờ (24 giờ, bước 5 phút).
class TimeWheel extends StatelessWidget {
  const TimeWheel({super.key, required this.initial, required this.onChanged});

  final int initial;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = initial - initial % 5;
    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: theme.brightness,
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle: TextStyle(fontSize: 24, color: theme.colorScheme.onSurface),
        ),
      ),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        use24hFormat: true,
        minuteInterval: 5,
        initialDateTime: DateTime(2000, 1, 1, start ~/ 60, start % 60),
        onDateTimeChanged: (d) {
          HapticFeedback.selectionClick();
          onChanged(d.hour * 60 + d.minute);
        },
      ),
    );
  }
}

/// Bảng chọn giờ; trả về số phút từ 0 giờ, hoặc null nếu đóng.
Future<int?> showTimeSheet(BuildContext context, {required int initial, required String title}) {
  var value = initial - initial % 5;
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(
            height: 190,
            child: TimeWheel(initial: value, onChanged: (m) => value = m),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('Xong')),
        ],
      ),
    ),
  );
}

/// Kết quả của bảng chỉnh nhắc nhở: [reminder] null nghĩa là đã tắt nhắc.
class ReminderSheetResult {
  const ReminderSheetResult(this.reminder);
  final HabitReminder? reminder;
}

/// Bảng chỉnh giờ và các ngày nhắc cho một thói quen.
Future<ReminderSheetResult?> showHabitReminderSheet(
  BuildContext context, {
  required String emoji,
  required String name,
  required int suggestedMinutes,
  HabitReminder? initial,
  String? hint,
}) {
  return showModalBottomSheet<ReminderSheetResult>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _HabitReminderSheet(
      emoji: emoji,
      name: name,
      hint: hint,
      initial: initial,
      suggestedMinutes: suggestedMinutes,
    ),
  );
}

class _HabitReminderSheet extends StatefulWidget {
  const _HabitReminderSheet({
    required this.emoji,
    required this.name,
    required this.suggestedMinutes,
    this.initial,
    this.hint,
  });

  final String emoji;
  final String name;
  final int suggestedMinutes;
  final HabitReminder? initial;
  final String? hint;

  @override
  State<_HabitReminderSheet> createState() => _HabitReminderSheetState();
}

class _HabitReminderSheetState extends State<_HabitReminderSheet> {
  late int _minutes = widget.initial?.minutes ?? widget.suggestedMinutes;
  late final Set<int> _days = {...(widget.initial?.weekdays ?? allWeekdays)};

  void _preset(Set<int> days) {
    HapticFeedback.selectionClick();
    setState(
      () => _days
        ..clear()
        ..addAll(days),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = {
      'Mỗi ngày': allWeekdays,
      'Ngày thường': {1, 2, 3, 4, 5},
      'Cuối tuần': {6, 7},
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.name,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.hint!,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          SizedBox(
            height: 170,
            child: TimeWheel(initial: _minutes, onChanged: (m) => _minutes = m),
          ),
          Text('Nhắc vào các ngày', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++)
                _DayDot(
                  label: weekdayShort[d - 1],
                  selected: _days.contains(d),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      // Luôn giữ ít nhất một ngày.
                      if (_days.contains(d) && _days.length > 1) {
                        _days.remove(d);
                      } else {
                        _days.add(d);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final e in presets.entries)
                ChoiceChip(
                  label: Text(e.key),
                  selected: _days.length == e.value.length && _days.containsAll(e.value),
                  onSelected: (_) => _preset(e.value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.initial != null) ...[
                TextButton(
                  onPressed: () => Navigator.pop(context, const ReminderSheetResult(null)),
                  child: const Text('Tắt nhắc'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    ReminderSheetResult(HabitReminder(minutes: _minutes, weekdays: {..._days})),
                  ),
                  child: Text('Nhắc lúc ${formatHm(_minutes)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [WaterColors.light, WaterColors.deep],
                )
              : null,
          color: selected ? null : theme.colorScheme.surfaceContainerHighest,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
