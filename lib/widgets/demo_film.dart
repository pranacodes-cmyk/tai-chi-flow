import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Our bundled films are square by contract (`scripts/media/encode-film.py`), so they are
/// laid out square: a file with stray pixel-aspect metadata then still plays undistorted.
/// Licensed network media keeps its own shape.
Size filmBox(VideoPlayerController c, {required bool square}) =>
    square ? Size.square(c.value.size.height) : c.value.size;

/// How far the player may enlarge a square film past the box width (web `FILM_MAX_ZOOM`).
/// 1.2 trims about 8% of plain wall per side; every film keeps at least 11% side margin.
const double kFilmMaxZoom = 1.2;

/// Muted looping demo film for an exercise (web `DemoFilm`): licensed network media first,
/// then our bundled demo asset. Shows the pose photo until the film is ready, and keeps it on failure.
class DemoFilm extends StatefulWidget {
  const DemoFilm({
    super.key,
    required this.exercise,
    this.playing = true,
    this.contain = false,
    this.alignment = const Alignment(0, -0.3),
  });
  final Exercise exercise;
  final bool playing;
  final bool contain;
  final Alignment alignment;
  @override
  State<DemoFilm> createState() => _DemoFilmState();
}

class _DemoFilmState extends State<DemoFilm> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final film = widget.exercise.film;
    if (film == null) return;
    final options = VideoPlayerOptions(mixWithOthers: true);
    final c = film.asset
        ? VideoPlayerController.asset(film.src, videoPlayerOptions: options)
        : VideoPlayerController.networkUrl(
            Uri.parse(film.src),
            videoPlayerOptions: options,
          );
    _c = c;
    c.setLooping(true);
    c.setVolume(0);
    c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          if (widget.playing) c.play();
        })
        .catchError((Object _) {
          // photo stays visible
        });
  }

  @override
  void didUpdateWidget(covariant DemoFilm old) {
    super.didUpdateWidget(old);
    final c = _c;
    if (c == null || !_ready) return;
    widget.playing ? c.play() : c.pause();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (widget.contain) return _contained(c);
    return ColoredBox(
      color: C.sand,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EImage(img(widget.exercise.image)),
          if (c != null && _ready)
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 500),
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: widget.alignment,
                  child: SizedBox.fromSize(
                    size: filmBox(c, square: widget.exercise.film!.asset),
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Player layout (web `DemoFilm` contain): the square film fills the box's full height, up to
  /// [kFilmMaxZoom] x its width (trimming only plain side wall, every film keeps more side margin
  /// than that), standing on the bottom edge. No soft band sits between the film's top edge and
  /// raised hands on normal phones; only an unusually tall box leaves a small wall strip above.
  Widget _contained(VideoPlayerController? c) {
    return ColoredBox(
      color: C.sand,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          final side = h >= w ? math.min(h, w * kFilmMaxZoom) : h;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (side < h || side < w)
                Positioned.fill(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Transform.scale(
                        scale: 1.1,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: 1 / 30,
                              child: Image.asset(img(widget.exercise.image)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: (w - side) / 2,
                bottom: 0,
                width: side,
                height: side,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(img(widget.exercise.image), fit: BoxFit.cover),
                    if (c != null && _ready)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox.fromSize(
                          size: filmBox(c, square: widget.exercise.film!.asset),
                          child: VideoPlayer(c),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
