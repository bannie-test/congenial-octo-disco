import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/habit.dart';
import '../models/inbox_item.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/drop_buddy.dart';
import '../widgets/droplet_fx.dart';
import '../widgets/in_app_banner.dart';
import '../widgets/liquid.dart';
import '../widgets/ringing_bell.dart';
import '../widgets/sprout.dart';
import 'add_habit_sheet.dart';
import 'craving_screen.dart';
import 'notifications_screen.dart';
import 'reminders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _sproutKey = GlobalKey<SproutViewState>();
  final _gaugeKey = GlobalKey<LiquidDropState>();
  late AppState _state;
  InAppBanners? _banners;
  StreamSubscription<InboxItem>? _events;
  StreamSubscription<String>? _taps;
  Timer? _ticker;
  int _ticks = 0;
  final _batch = <InboxItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cập nhật bộ đếm "sạch" mỗi giây cho cảm giác thời gian đang trôi,
    // và thỉnh thoảng kiểm tra cột mốc mới (ví dụ vừa qua nửa đêm).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (++_ticks % 20 == 0) _state.refreshEvents();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
    _banners ??= InAppBanners(Overlay.of(context));
  }

  Future<void> _listen() async {
    if (!mounted) return;
    final state = _state;
    _events = state.events.listen(_onEvent);
    state.takeUndelivered().forEach(_onEvent);
    _taps = state.notifications.taps.listen(_openPayload);
    unawaited(state.refreshPermission());
    final launch = await state.notifications.launchPayload();
    if (launch != null) _openPayload(launch);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    // Người dùng có thể vừa bật/tắt thông báo trong Cài đặt.
    _state.refreshPermission();
    _state.refreshEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _events?.cancel();
    _taps?.cancel();
    _banners?.dispose();
    super.dispose();
  }

  /// Một lần chạm có thể sinh vài thành tích cùng lúc (lên cấp, chuỗi ngày…):
  /// gom lại và chỉ hiện banner quan trọng nhất, phần còn lại nằm trong hộp thư.
  void _onEvent(InboxItem item) {
    if (_batch.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _flushEvents());
      SchedulerBinding.instance.ensureVisualUpdate();
    }
    _batch.add(item);
  }

  static int _priority(InboxKind kind) => switch (kind) {
    InboxKind.daily => 4,
    InboxKind.level => 3,
    InboxKind.clean => 2,
    InboxKind.streak => 1,
    _ => 0,
  };

  void _flushEvents() {
    if (!mounted || _batch.isEmpty) return;
    final items = List.of(_batch)..sort((a, b) => _priority(b.kind).compareTo(_priority(a.kind)));
    _batch.clear();
    if (items.first.kind == InboxKind.daily) {
      // Hoàn thành đủ thói quen: giọt nước hôm nay bung ra ăn mừng.
      final gauge = _visibleCenter(_gaugeKey);
      if (gauge != null) launchDropletBurst(context, gauge);
    }
    _banners?.show(
      items.first,
      delay: const Duration(milliseconds: 650),
      onTap: () => Navigator.of(context).push(NotificationsScreen.route()),
    );
  }

  void _openPayload(String payload) {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (payload == 'inbox') {
      nav.push(NotificationsScreen.route());
    } else if (payload.startsWith('craving:')) {
      final id = payload.substring('craving:'.length);
      final habit = _state.badHabits.where((h) => h.id == id).firstOrNull;
      if (habit != null) nav.push(CravingScreen.route(habit, _state));
    }
  }

  /// Toạ độ trên màn hình của một điểm trong widget, nếu widget đang hiển thị.
  Offset? _visiblePoint(GlobalKey key, Offset Function(Size size) at) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final p = box.localToGlobal(at(box.size));
    final screen = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return p.dy > top + 24 && p.dy < screen.height - 24 ? p : null;
  }

  Offset? _visibleCenter(GlobalKey key) => _visiblePoint(key, (s) => s.center(Offset.zero));

  /// Thả một giọt nước từ thói quen vừa hoàn thành vào chậu cây
  /// (hoặc vào giọt nước hôm nay nếu cây đã cuộn khỏi màn hình).
  void _water(GlobalKey source) {
    final from = _visibleCenter(source);
    if (from == null) return;
    final pot = _visiblePoint(_sproutKey, (s) => Offset(s.width / 2, s.height * 0.7));
    if (pot != null) {
      launchDroplet(context, from: from, to: pot, onLand: () => _sproutKey.currentState?.water());
      return;
    }
    final gauge = _visibleCenter(_gaugeKey);
    if (gauge != null) {
      launchDroplet(context, from: from, to: gauge, onLand: () => _gaugeKey.currentState?.splash());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final showPrompt = !state.reminders.enabled && !state.reminderPromptDismissed;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(child: _Header(state: state)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _PlantCard(state: state, sproutKey: _sproutKey),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _TodayCard(state: state, gaugeKey: _gaugeKey),
            ),
          ),
          if (showPrompt)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _ReminderPrompt(state: state)),
            ),
          _SectionHeader(title: 'Thói quen tốt hôm nay', onAdd: () => showAddHabitSheet(context, bad: false)),
          if (state.goodHabits.isEmpty) const _EmptyHint(text: 'Thêm một thói quen nhỏ để mầm bắt đầu lớn.'),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: state.goodHabits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _GoodHabitTile(
                key: ValueKey(state.goodHabits[i].id),
                habit: state.goodHabits[i],
                state: state,
                onWatered: _water,
              ),
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

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  static String _greeting(DateTime t) => switch (t.hour) {
    >= 5 && < 11 => 'Chào buổi sáng ☀️',
    >= 11 && < 14 => 'Buổi trưa vui vẻ 🌤️',
    >= 14 && < 18 => 'Chào buổi chiều 🌿',
    >= 18 && < 22 => 'Buổi tối an lành 🌙',
    _ => 'Khuya rồi, ngủ sớm nhé 😴',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = state.now;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(now),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  formatDate(now),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Nhắc nhở',
            onPressed: () => Navigator.of(context).push(RemindersScreen.route()),
            icon: Icon(state.reminders.enabled ? Icons.alarm_on_rounded : Icons.alarm_rounded),
          ),
          RingingBell(
            count: state.unreadCount,
            onPressed: () => Navigator.of(context).push(NotificationsScreen.route()),
          ),
        ],
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.state, required this.sproutKey});
  final AppState state;
  final GlobalKey<SproutViewState> sproutKey;

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
          SproutView(key: sproutKey, growth: state.stage + state.stageProgress, vitality: v, size: 230),
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

/// Giọt nước lớn cho biết hôm nay đã "tưới" Mầm được bao nhiêu.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state, required this.gaugeKey});
  final AppState state;
  final GlobalKey<LiquidDropState> gaugeKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final total = state.goodHabits.length;
    final done = state.doneTodayCount;
    final progress = state.todayProgress;
    final hint = total == 0
        ? 'Thêm thói quen để bắt đầu tưới Mầm.'
        : done == total
        ? 'Đã tưới đủ hôm nay 💧'
        : 'Còn ${total - done} giọt nữa là đầy!';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            LiquidDrop(
              key: gaugeKey,
              level: progress,
              size: const Size(92, 120),
              label: '${(progress * 100).round()}%',
              glassColor: dark ? WaterColors.glassDark : WaterColors.glass,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tưới Mầm hôm nay',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$done/$total',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: dark ? WaterColors.light : WaterColors.deep,
                          ),
                        ),
                        TextSpan(text: '  giọt', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      hint,
                      key: ValueKey(hint),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đã tiết kiệm ${formatVnd(state.totalMoneySaved)}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
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

class _ReminderPrompt extends StatelessWidget {
  const _ReminderPrompt({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(0, 4, 40, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: dark
                  ? const [Color(0xFF15303F), Color(0xFF1A2830)]
                  : const [Color(0xFFDDF3FF), Color(0xFFF3FBFF)],
            ),
          ),
          child: Row(
            children: [
              const DropBuddy(size: 46, bell: true),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Để Mầm nhắc bạn nhé',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nhắc uống nước, giữ thói quen và chúc mừng mỗi cột mốc.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: () => state.enableReminders(),
                      child: const Text('Bật nhắc nhở'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            tooltip: 'Để sau',
            onPressed: state.dismissReminderPrompt,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ),
      ],
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

class _GoodHabitTile extends StatefulWidget {
  const _GoodHabitTile({super.key, required this.habit, required this.state, required this.onWatered});
  final GoodHabit habit;
  final AppState state;

  /// Gọi khi vừa hoàn thành, kèm vị trí để thả giọt nước bay đi.
  final void Function(GlobalKey source) onWatered;

  @override
  State<_GoodHabitTile> createState() => _GoodHabitTileState();
}

class _GoodHabitTileState extends State<_GoodHabitTile> {
  final _checkKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final state = widget.state;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final done = habit.isDoneOn(state.now);
    final streak = habit.streak(state.now);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        final nowDone = state.toggleToday(habit);
        if (nowDone) {
          HapticFeedback.mediumImpact();
          widget.onWatered(_checkKey);
        } else {
          HapticFeedback.selectionClick();
        }
      },
      onLongPress: () async {
        if (await _confirmDelete(context, habit.name)) state.removeGoodHabit(habit.id);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(22)),
        child: WaterFill(
          filled: done,
          topColor: dark ? const Color(0xFF1D5F80) : const Color(0xFFD3F1FF),
          bottomColor: dark ? const Color(0xFF134A66) : const Color(0xFFA6DFFF),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done
                        ? Colors.white.withValues(alpha: dark ? 0.12 : 0.55)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
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
                          decorationColor: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        streak > 0 ? '🔥 $streak ngày liên tiếp' : 'Chạm để tưới một giọt cho Mầm',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  key: _checkKey,
                  width: 34,
                  height: 34,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                      child: child,
                    ),
                    child: done
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey(true),
                            color: dark ? WaterColors.light : WaterColors.deep,
                            size: 34,
                          )
                        : Icon(
                            Icons.circle_outlined,
                            key: const ValueKey(false),
                            color: scheme.outlineVariant,
                            size: 34,
                          ),
                  ),
                ),
              ],
            ),
          ),
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
