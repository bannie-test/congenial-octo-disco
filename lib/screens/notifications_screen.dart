import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/inbox_item.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/drop_buddy.dart';
import '../widgets/inbox_style.dart';
import '../widgets/liquid.dart';
import 'reminders_screen.dart';

/// Hộp thông báo: thành tích, cột mốc và lời nhắn từ Mầm.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const NotificationsScreen());

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late AppState _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
  }

  @override
  void dispose() {
    _enter.dispose();
    // Rời màn hình nghĩa là đã xem hết.
    WidgetsBinding.instance.addPostFrameCallback((_) => _state.markAllRead());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final groups = _group(state.inbox, state.now);
    var index = 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Thông báo'),
            actions: [
              if (state.unreadCount > 0)
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    state.markAllRead();
                  },
                  child: const Text('Đọc hết'),
                ),
              IconButton(
                tooltip: 'Cài đặt nhắc nhở',
                onPressed: () => Navigator.of(context).push(RemindersScreen.route()),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          if (state.inbox.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const DropBuddy(size: 96, mood: DropMood.sleepy, level: 0.35),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có thông báo nào',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hoàn thành thói quen và giữ chuỗi ngày, Mầm sẽ gửi lời khen cho bạn ở đây.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          for (final (label, items) in groups) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  for (final item in items)
                    _Entrance(
                      key: ValueKey(item.id),
                      animation: _enter,
                      index: index++,
                      child: _InboxTile(item: item, state: state),
                    ),
                ],
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }

  static List<(String, List<InboxItem>)> _group(List<InboxItem> items, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <String, List<InboxItem>>{};
    for (final item in items) {
      final day = DateTime(item.at.year, item.at.month, item.at.day);
      final label = switch (today.difference(day).inDays) {
        0 => 'Hôm nay',
        1 => 'Hôm qua',
        _ => 'Trước đó',
      };
      buckets.putIfAbsent(label, () => []).add(item);
    }
    return [for (final e in buckets.entries) (e.key, e.value)];
  }
}

/// Trượt và hiện dần theo thứ tự khi mở màn hình.
class _Entrance extends StatelessWidget {
  const _Entrance({super.key, required this.animation, required this.index, required this.child});

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, (1 - curved.value) * 24), child: child),
      ),
      child: child,
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.state});

  final InboxItem item;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('dismiss-${item.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          HapticFeedback.lightImpact();
          state.removeInbox(item.id);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
        ),
        child: Material(
          color: item.read ? theme.cardTheme.color : _unreadTint(theme),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => state.markRead(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InboxBubble(kind: item.kind, emoji: item.emoji),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                                ),
                              ),
                            ),
                            AnimatedScale(
                              scale: item.read ? 0 : 1,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: WaterColors.mid,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatAgo(item.at, state.now),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _unreadTint(ThemeData theme) =>
      theme.brightness == Brightness.dark ? const Color(0xFF16303D) : const Color(0xFFEAF6FF);
}
