import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/reminder.dart';
import '../utils/format.dart';
import '../widgets/time_sheet.dart';

const _goodEmojis = ['💧', '🏃', '📖', '😴', '🧘', '🥗', '✍️', '🎸', '🧹', '🙏', '💊', '🌞'];
const _badEmojis = ['🧋', '📱', '🚬', '🍺', '🍟', '🛍️', '🎮', '🤬', '☕', '🍬', '😤', '🛌'];

Future<void> showAddHabitSheet(BuildContext context, {required bool bad}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AddHabitSheet(bad: bad),
  );
}

class AddHabitSheet extends StatefulWidget {
  const AddHabitSheet({super.key, required this.bad});
  final bool bad;

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<AddHabitSheet> {
  final _name = TextEditingController();
  final _cost = TextEditingController();
  late String _emoji = (widget.bad ? _badEmojis : _goodEmojis).first;
  bool _remind = false;
  late int _remindAt = widget.bad ? 15 * 60 : 20 * 60;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final state = AppScope.of(context);
    final reminder = _remind ? HabitReminder(minutes: _remindAt) : null;
    if (widget.bad) {
      state.addBadHabit(name, _emoji, costPerDay: int.tryParse(_cost.text) ?? 0, reminder: reminder);
    } else {
      state.addGoodHabit(name, _emoji, reminder: reminder);
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emojis = widget.bad ? _badEmojis : _goodEmojis;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.bad ? 'Thói quen muốn bỏ' : 'Thói quen muốn xây',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in emojis)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _emoji = e);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == _emoji
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: e == _emoji ? theme.colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: widget.bad ? 'Ví dụ: Uống trà sữa' : 'Ví dụ: Chạy bộ 15 phút',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (widget.bad) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Chi phí mỗi ngày (không bắt buộc)',
                suffixText: 'đ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
            title: Text(widget.bad ? '🔔 Nhắc trước giờ hay thèm' : '🔔 Nhắc tôi mỗi ngày'),
            subtitle: GestureDetector(
              onTap: () async {
                final m = await showTimeSheet(context, initial: _remindAt, title: 'Giờ nhắc');
                if (m != null) setState(() => _remindAt = m);
              },
              child: Text(
                'Lúc ${formatHm(_remindAt)} · chạm để đổi giờ',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Thêm')),
        ],
      ),
    );
  }
}
