import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';

/// Horizontal ruler picker (web `RulerPicker`): 12px per tick, center indicator, snapping.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.majorEvery = 10,
    this.background = C.cream,
  });
  final int value, min, max, majorEvery;
  final ValueChanged<int> onChanged;
  final Color background;
  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  static const tick = 12.0;
  late final ScrollController _ctrl = ScrollController(
    initialScrollOffset: (widget.value - widget.min) * tick,
  );
  int _last = 0;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _last = widget.value;
  }

  @override
  void didUpdateWidget(covariant RulerPicker old) {
    super.didUpdateWidget(old);
    if (!_userScrolling && (widget.value != _last || widget.min != old.min)) {
      _last = widget.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) {
          _ctrl.jumpTo(
            ((widget.value - widget.min) * tick).clamp(
              0,
              (widget.max - widget.min) * tick,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _emit() {
    final idx = (_ctrl.offset / tick).round().clamp(0, widget.max - widget.min);
    final v = widget.min + idx;
    if (v != _last) {
      _last = v;
      Haptics.select();
      widget.onChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.max - widget.min;
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.maxWidth / 2 - tick / 2;
        return SizedBox(
          height: 88,
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) {
                    _userScrolling = true;
                  }
                  if (n is ScrollUpdateNotification) _emit();
                  if (n is ScrollEndNotification) {
                    _userScrolling = false;
                    final target = (_ctrl.offset / tick).round() * tick;
                    if ((target - _ctrl.offset).abs() > 0.5) {
                      Future.microtask(
                        () => _ctrl.animateTo(
                          target,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                      );
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: side),
                  itemExtent: tick,
                  itemCount: count + 1,
                  itemBuilder: (_, i) {
                    final v = widget.min + i;
                    final major = v % widget.majorEvery == 0;
                    final half = !major && v % (widget.majorEvery ~/ 2) == 0;
                    return SizedBox(
                      width: tick,
                      child: OverflowBox(
                        maxWidth: 40,
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            Container(
                              width: 2,
                              height: major ? 44 : (half ? 32 : 20),
                              decoration: BoxDecoration(
                                color: C.ink.withValues(
                                  alpha: major ? 0.55 : (half ? 0.3 : 0.18),
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            if (major) ...[
                              const SizedBox(height: 8),
                              Text('$v', style: T.tiny.tab),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              IgnorePointer(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.background,
                            widget.background.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.background.withValues(alpha: 0),
                            widget.background,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 3,
                    height: 64,
                    decoration: BoxDecoration(
                      color: C.jade,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
