import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'liquid.dart';

/// Nút chuông có huy hiệu số chưa đọc; rung lên mỗi khi có thông báo mới.
class RingingBell extends StatefulWidget {
  const RingingBell({super.key, required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  State<RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<RingingBell> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didUpdateWidget(RingingBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) _ring.forward(from: 0);
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Thông báo',
      onPressed: widget.onPressed,
      icon: AnimatedBuilder(
        animation: _ring,
        builder: (context, child) {
          final t = _ring.value;
          final angle = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 7) * (1 - t) * 0.5;
          return Transform.rotate(angle: angle, alignment: Alignment.topCenter, child: child);
        },
        child: Badge.count(
          count: widget.count,
          isLabelVisible: widget.count > 0,
          backgroundColor: WaterColors.deep,
          child: const Icon(Icons.notifications_rounded),
        ),
      ),
    );
  }
}
