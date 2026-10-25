import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/habit.dart';
import '../models/journal.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

/// Nhật ký cảm xúc: chọn cảm xúc chủ đạo trong ngày và ghi chú.
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final _note = TextEditingController();
  String? _moodId;
  String? _loadedDay;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _syncWithToday(AppState state) {
    final key = dayKey(state.now);
    if (_loadedDay == key) return;
    _loadedDay = key;
    final entry = state.moodOn(state.now);
    _moodId = entry?.moodId;
    _note.text = entry?.note ?? '';
  }

  void _save(AppState state) {
    final id = _moodId;
    if (id == null) return;
    state.setMood(state.now, id, _note.text);
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã lưu cảm xúc hôm nay: ${moodById(id).emoji} ${moodById(id).label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _syncWithToday(state);
    final theme = Theme.of(context);
    final history = state.moods.values.toList()..sort((a, b) => b.day.compareTo(a.day));
    final saved = state.moodOn(state.now);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Cảm xúc')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList.list(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Hôm nay bạn thấy thế nào?',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          formatDate(state.now),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.85,
                          children: [
                            for (final m in moods)
                              _MoodBubble(
                                mood: m,
                                selected: m.id == _moodId,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _moodId = m.id);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _note,
                          minLines: 2,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Ghi chú: điều gì khiến bạn thấy vậy?',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _moodId == null ? null : () => _save(state),
                          child: Text(saved == null ? 'Lưu cảm xúc' : 'Cập nhật'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('7 ngày qua', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 6; i >= 0; i--)
                      _WeekDot(day: dayOffset(state.now, -i), entry: state.moodOn(dayOffset(state.now, -i))),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Nhật ký', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (history.isEmpty)
                  Text(
                    'Chưa có ghi chép nào. Mỗi ngày chọn một cảm xúc, dần dần bạn sẽ hiểu mình hơn.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                for (final e in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey('mood-${e.day}'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => state.removeMood(e.day),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
                      ),
                      child: _EntryTile(entry: e),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodBubble extends StatelessWidget {
  const _MoodBubble({required this.mood, required this.selected, required this.onTap});
  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: selected
                ? mood.color.withValues(alpha: 0.35)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? mood.color : Colors.transparent, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(mood.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 4),
              Text(
                mood.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.day, required this.entry});
  final DateTime day;
  final MoodEntry? entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: e == null
                ? theme.colorScheme.surfaceContainerHighest
                : e.mood.color.withValues(alpha: 0.35),
          ),
          child: Text(e?.mood.emoji ?? '·', style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 4),
        Text(weekdayShort[day.weekday - 1], style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final MoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = entry.mood;
    final day = DateTime.parse(entry.day);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: m.color.withValues(alpha: 0.35), shape: BoxShape.circle),
              child: Text(m.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    formatDate(day),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                  if (entry.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(entry.note, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
