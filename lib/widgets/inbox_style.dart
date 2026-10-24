import 'package:flutter/material.dart';

import '../models/inbox_item.dart';

/// Màu chuyển sắc cho từng loại thông báo.
List<Color> inboxColors(InboxKind kind) => switch (kind) {
  InboxKind.welcome => const [Color(0xFF9BE7C4), Color(0xFF3FA66B)],
  InboxKind.level => const [Color(0xFF8FE3A0), Color(0xFF2E9D5B)],
  InboxKind.streak => const [Color(0xFFFFC07A), Color(0xFFFF7A45)],
  InboxKind.clean => const [Color(0xFFFFDE7A), Color(0xFFF2A516)],
  InboxKind.daily => const [Color(0xFF7FD8FF), Color(0xFF1E8FE0)],
  InboxKind.relapse => const [Color(0xFFC3CCFF), Color(0xFF7C8CF0)],
};

/// Biểu tượng tròn chứa emoji của thông báo.
class InboxBubble extends StatelessWidget {
  const InboxBubble({super.key, required this.kind, required this.emoji, this.size = 46});

  final InboxKind kind;
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = inboxColors(kind);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [
          BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
    );
  }
}
