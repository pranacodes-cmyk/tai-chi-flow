import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

/// Top toast matching the web toast (glass card, spring in, auto-dismiss).
class Toast {
  Toast._();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    String title, {
    String? description,
    String tone = 'default',
  }) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _timer?.cancel();
    _entry?.remove();
    final key = GlobalKey<_ToastViewState>();
    _entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: key,
        title: title,
        description: description,
        tone: tone,
        onDismiss: hide,
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(const Duration(milliseconds: 3200), () async {
      await key.currentState?.out();
      hide();
    });
  }

  static void hide() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.title,
    this.description,
    required this.tone,
    required this.onDismiss,
  });
  final String title;
  final String? description;
  final String tone;
  final VoidCallback onDismiss;
  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();
  Future<void> out() async {
    if (mounted) await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final premium = widget.tone == 'premium';
    final a = CurvedAnimation(
      parent: _c,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      top: top + 10,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: a,
        builder: (_, child) => Opacity(
          opacity: _c.value,
          child: Transform.translate(
            offset: Offset(0, -24 * (1 - a.value)),
            child: Transform.scale(scale: 0.96 + 0.04 * a.value, child: child),
          ),
        ),
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: premium ? C.ink : C.ivory.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: S.card,
                    border: Border.all(color: C.ivory.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: T.label.copyWith(
                          color: premium ? C.ivory : C.ink,
                        ),
                      ),
                      if (widget.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.description!,
                          style: T.caption.copyWith(
                            color: premium
                                ? C.ivory.withValues(alpha: 0.7)
                                : C.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
