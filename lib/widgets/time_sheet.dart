import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reminder.dart';
import '../utils/format.dart';
import 'droplet_fx.dart';
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

/// Bảng chỉnh nhắc cho một thói quen: giờ cố định hoặc lặp lại theo chu kỳ,
/// cùng các thứ trong tuần.
Future<ReminderSheetResult?> showHabitReminderSheet(
  BuildContext context, {
  required String emoji,
  required String name,
  required int suggestedMinutes,
  HabitReminder? initial,
  String? hint,
  bool allowInterval = true,
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
      allowInterval: allowInterval,
    ),
  );
}

class _HabitReminderSheet extends StatefulWidget {
  const _HabitReminderSheet({
    required this.emoji,
    required this.name,
    required this.suggestedMinutes,
    required this.allowInterval,
    this.initial,
    this.hint,
  });

  final String emoji;
  final String name;
  final int suggestedMinutes;
  final bool allowInterval;
  final HabitReminder? initial;
  final String? hint;

  @override
  State<_HabitReminderSheet> createState() => _HabitReminderSheetState();
}

class _HabitReminderSheetState extends State<_HabitReminderSheet> {
  static const _presets = [30, 60, 90, 120, 180];

  late ReminderMode _mode = widget.initial?.mode ?? ReminderMode.fixed;
  late int _minutes = widget.initial?.minutes ?? widget.suggestedMinutes;
  late int _every = widget.initial?.every ?? 120;
  late int _from = widget.initial?.from ?? 8 * 60;
  late int _to = widget.initial?.to ?? 20 * 60;
  late final Set<int> _days = {...(widget.initial?.weekdays ?? allWeekdays)};
  late bool _custom = !_presets.contains(_every);
  late final _hours = TextEditingController(text: '${_every ~/ 60}');
  late final _mins = TextEditingController(text: '${_every % 60}');

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  HabitReminder get _result => HabitReminder(
    mode: _mode,
    minutes: _minutes,
    every: _every,
    from: _from,
    to: _to,
    weekdays: {..._days},
  );

  void _readCustom() {
    final total = (int.tryParse(_hours.text) ?? 0) * 60 + (int.tryParse(_mins.text) ?? 0);
    setState(() => _every = math.max(HabitReminder.minEvery, total));
  }

  Future<void> _pickRange({required bool from}) async {
    final m = await showTimeSheet(
      context,
      initial: from ? _from : _to,
      title: from ? 'Bắt đầu nhắc từ' : 'Nhắc đến',
    );
    if (m == null) return;
    setState(() {
      if (from) {
        _from = m;
        _to = math.max(_to, m);
      } else {
        _to = m;
        _from = math.min(_from, m);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = {
      'Mỗi ngày': allWeekdays,
      'Ngày thường': {1, 2, 3, 4, 5},
      'Cuối tuần': {6, 7},
    };
    final slots = _result.slots;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
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
          if (widget.allowInterval) ...[
            const SizedBox(height: 14),
            SegmentedButton<ReminderMode>(
              segments: const [
                ButtonSegment(
                  value: ReminderMode.fixed,
                  icon: Icon(Icons.schedule_rounded),
                  label: Text('Giờ cố định'),
                ),
                ButtonSegment(
                  value: ReminderMode.interval,
                  icon: Icon(Icons.repeat_rounded),
                  label: Text('Lặp lại'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                setState(() => _mode = s.first);
              },
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _mode == ReminderMode.fixed
                ? SizedBox(
                    height: 170,
                    child: TimeWheel(initial: _minutes, onChanged: (m) => _minutes = m),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhắc mỗi',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in _presets)
                              ChoiceChip(
                                label: Text(formatEvery(m)),
                                selected: !_custom && _every == m,
                                onSelected: (_) => setState(() {
                                  _custom = false;
                                  _every = m;
                                }),
                              ),
                            ChoiceChip(
                              label: const Text('Tuỳ chỉnh'),
                              selected: _custom,
                              onSelected: (_) {
                                setState(() => _custom = true);
                                _readCustom();
                              },
                            ),
                          ],
                        ),
                        if (_custom) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _NumberBox(controller: _hours, suffix: 'giờ', onChanged: _readCustom),
                              const SizedBox(width: 10),
                              _NumberBox(controller: _mins, suffix: 'phút', onChanged: _readCustom),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text('Từ', style: theme.textTheme.bodyMedium),
                            const SizedBox(width: 8),
                            TimePill(minutes: _from, onTap: () => _pickRange(from: true)),
                            const SizedBox(width: 12),
                            Text('đến', style: theme.textTheme.bodyMedium),
                            const SizedBox(width: 8),
                            TimePill(minutes: _to, onTap: () => _pickRange(from: false)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SlotTimeline(slots: slots, now: DateTime.now()),
                        Text(
                          '${slots.length} lần mỗi ngày',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
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
                  onSelected: (_) => setState(
                    () => _days
                      ..clear()
                      ..addAll(e.value),
                  ),
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
                  onPressed: slots.isEmpty
                      ? null
                      : () => Navigator.pop(context, ReminderSheetResult(_result)),
                  child: Text(
                    _mode == ReminderMode.fixed ? 'Nhắc lúc ${formatHm(_minutes)}' : 'Lưu nhắc lặp lại',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberBox extends StatelessWidget {
  const _NumberBox({required this.controller, required this.suffix, required this.onChanged});

  final TextEditingController controller;
  final String suffix;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        textAlign: TextAlign.center,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          suffixText: suffix,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// Ô hiện giờ dạng viên thuốc, chạm để đổi giờ.
class TimePill extends StatelessWidget {
  const TimePill({super.key, required this.minutes, required this.onTap, this.enabled = true});

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

/// Dòng thời gian 5h–24h với các giọt nước đánh dấu giờ nhắc.
class SlotTimeline extends StatelessWidget {
  const SlotTimeline({super.key, required this.slots, required this.now});

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
          double x(int m) => (m.clamp(_start, _end) - _start) / (_end - _start) * c.maxWidth;
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
                width: x(nowMin),
                top: 30,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [WaterColors.light, WaterColors.mid]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              for (final (i, m) in slots.take(48).indexed)
                Positioned(
                  key: ValueKey(m),
                  left: x(m) - 7,
                  top: 6,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 350 + i * 30),
                    curve: Interval(i * 30 / (350 + i * 30), 1, curve: Curves.easeOutBack),
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
