import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/tokens.dart';

/// Full-bleed cinematic tutor film (16:9), looping; mirrors web PaywallFilm.
class PaywallFilm extends StatefulWidget {
  const PaywallFilm({super.key});
  @override
  State<PaywallFilm> createState() => _PaywallFilmState();
}

class _PaywallFilmState extends State<PaywallFilm> {
  final _controller = VideoPlayerController.asset('assets/video/paywall-mountain.mp4', videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) async {
      await _controller.setVolume(0);
      await _controller.setLooping(true);
      if (!mounted) return;
      setState(() => _ready = true);
      if (!MediaQuery.disableAnimationsOf(context)) await _controller.play();
    }).catchError((Object _) {});
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: C.sand,
        child: SizedBox.expand(
          child: _ready
              ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)))
              : Image.asset('assets/images/paywall-mountain.jpg', fit: BoxFit.cover),
        ),
      );
}