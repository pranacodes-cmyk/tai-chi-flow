import 'package:flutter/material.dart';

import '../services/audio_service.dart';

class VoiceBars extends StatefulWidget {
  const VoiceBars({super.key, this.color = Colors.white, this.size = 18});
  final Color color;
  final double size;

  @override
  State<VoiceBars> createState() => _VoiceBarsState();
}

class _VoiceBarsState extends State<VoiceBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    Voice.speaking.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (Voice.speaking.value) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Voice.speaking.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: Voice.speaking.value ? 1 : 0,
    duration: const Duration(milliseconds: 200),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(4, (i) {
            final phase = (_controller.value * 4 + i * .72) % 2;
            final wave = phase <= 1 ? phase : 2 - phase;
            return Container(
              width: 2,
              height: widget.size * (.25 + .7 * wave),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
