import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Quiet concentric rings that grow over the whole inhale, stay full on the hold and settle over
/// the whole exhale. They start contracted so the very first inhale visibly grows with the voice
/// cue, and outer rings trail the inner one slightly like a wave of breath (web mirrors this).
class PreparationBreath extends StatefulWidget {
  const PreparationBreath({super.key, required this.expanded, required this.duration});
  final bool expanded;
  final int duration;

  @override
  State<PreparationBreath> createState() => _PreparationBreathState();
}

class _PreparationBreathState extends State<PreparationBreath> {
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final expanded = _armed && widget.expanded;
    final dur = reduced ? Duration.zero : Duration(milliseconds: widget.duration * 1000);
    return ExcludeSemantics(child: SizedBox(
      height: 150,
      width: double.infinity,
      child: Center(child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(alignment: Alignment.center, children: [
          for (final (index, diameter) in [146.0, 118.0, 90.0].indexed)
            AnimatedScale(
              scale: reduced ? 1 : expanded ? 1 : 0.62 + index * 0.08,
              duration: dur,
              // outer rings start a beat later than the inner one, all finish with the phase
              curve: Interval((2 - index) * 0.08, 1, curve: Curves.easeInOutSine),
              child: AnimatedContainer(
                duration: dur,
                curve: Curves.easeInOutSine,
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == 2 ? C.jadeSoft.withValues(alpha: expanded ? 0.8 : 0.45) : null,
                  border: Border.all(
                    color: index == 0
                        ? C.sage.withValues(alpha: expanded ? 0.55 : 0.25)
                        : index == 1
                            ? C.sage.withValues(alpha: expanded ? 0.8 : 0.5)
                            : C.jade.withValues(alpha: 0.7),
                    width: index == 2 ? 1.5 : 1,
                  ),
                ),
              ),
            ),
          const Icon(Icons.spa_outlined, size: 28, color: C.jade),
        ]),
      )),
    ));
  }
}
