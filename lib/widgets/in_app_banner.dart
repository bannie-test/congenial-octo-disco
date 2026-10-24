import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/inbox_item.dart';
import 'inbox_style.dart';

/// Hiện thông báo trong app dạng banner trượt xuống từ trên, tự ẩn sau vài
/// giây, vuốt lên để đóng, chạm để xem chi tiết. Banner mới thay ngay banner
/// đang hiện để phản hồi luôn khớp với hành động vừa làm.
class InAppBanners {
  InAppBanners(this._overlay);

  final OverlayState _overlay;
  (InboxItem, VoidCallback?)? _pending;
  OverlayEntry? _current;
  GlobalKey<_BannerCardState>? _currentKey;
  Timer? _delay;
  bool _disposed = false;

  void show(InboxItem item, {VoidCallback? onTap, Duration delay = Duration.zero}) {
    _pending = (item, onTap);
    _delay?.cancel();
    _delay = Timer(delay, () {
      _delay = null;
      if (_current == null) {
        _next();
      } else {
        // Đóng nhanh banner cũ; banner mới hiện ngay khi banner cũ khuất.
        _currentKey?.currentState?.close();
      }
    });
  }

  void _next() {
    final pending = _pending;
    if (_disposed || pending == null || !_overlay.mounted) return;
    _pending = null;
    final (item, onTap) = pending;
    final key = GlobalKey<_BannerCardState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerCard(
        key: key,
        item: item,
        onTap: onTap,
        onClosed: () {
          entry.remove();
          _current = null;
          _currentKey = null;
          if (_delay == null) _next();
        },
      ),
    );
    _current = entry;
    _currentKey = key;
    _overlay.insert(entry);
  }

  void dispose() {
    _disposed = true;
    _delay?.cancel();
    _pending = null;
  }
}

class _BannerCard extends StatefulWidget {
  const _BannerCard({super.key, required this.item, required this.onClosed, this.onTap});

  final InboxItem item;
  final VoidCallback onClosed;
  final VoidCallback? onTap;

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    reverseDuration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _hold;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _c.forward();
    _hold = Timer(const Duration(milliseconds: 3200), close);
  }

  void close() {
    if (_closing) return;
    _closing = true;
    _hold?.cancel();
    _c.reverse().then((_) {
      if (mounted) widget.onClosed();
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _slide.value) * -140),
          child: Opacity(opacity: _c.value, child: child),
        ),
        child: GestureDetector(
          onTap: () {
            widget.onTap?.call();
            close();
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -80) close();
          },
          child: Material(
            elevation: 12,
            shadowColor: Colors.black38,
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  InboxBubble(kind: item.kind, emoji: item.emoji, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
