import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../services/media_store.dart';
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

/// Opens one of our films: bundled → downloaded lesson copy → streamed from the media server.
/// [rel] is the media path (`video/<key>.mp4`); [network] is a licensed film URL instead.
VideoPlayerController openFilm({String? rel, String? network}) {
  final options = VideoPlayerOptions(mixWithOthers: true);
  if (rel != null && MediaStore.isBundled(rel)) {
    return VideoPlayerController.asset('assets/$rel', videoPlayerOptions: options);
  }
  final saved = rel == null ? null : MediaStore.cached(rel);
  if (saved != null) {
    return VideoPlayerController.file(saved, videoPlayerOptions: options);
  }
  if (rel != null) MediaStore.cacheInBackground(rel);
  return VideoPlayerController.networkUrl(
    Uri.parse(rel != null ? MediaStore.url(rel) : network!),
    videoPlayerOptions: options,
  );
}

/// Muted looping demo film for an exercise (web `DemoFilm`): licensed network media first,
/// then our bundled demo asset. [film] names a dedicated lesson film (`lf-*`) to play instead,
/// with its own poster. Shows the pose photo until the film is ready, and keeps it on failure.
/// Films loop natively: each one is encoded with its own seamless seam (scripts/media/encode-film.py),
/// so the player never blends two moments of the film (that blend double-exposed the instructor).
class DemoFilm extends StatefulWidget {
  const DemoFilm({
    super.key,
    required Exercise this.exercise,
    this.film,
    this.playing = true,
    this.contain = false,
    this.alignment = const Alignment(0, -0.3),
  });

  /// A lesson film on its own (the tutor's welcome / congratulations), filling the box (cover).
  const DemoFilm.lesson({
    super.key,
    required String this.film,
    this.playing = true,
    this.alignment = Alignment.center,
  }) : exercise = null,
       contain = false;
  final Exercise? exercise;
  final String? film;
  final bool playing;
  final bool contain;
  final Alignment alignment;
  @override
  State<DemoFilm> createState() => _DemoFilmState();
}

class _DemoFilmState extends State<DemoFilm> {
  VideoPlayerController? _c;
  bool _ready = false;

  String? get _rel {
    if (widget.film != null) return 'video/${widget.film}.mp4';
    final f = widget.exercise?.film;
    return f == null || !f.asset ? null : f.src.replaceFirst('assets/', '');
  }

  String get _poster => img(widget.film ?? widget.exercise!.image);

  /// Movement demos are square by contract; lesson films (`lf-*`, encoded with square pixels)
  /// keep their own shape, e.g. the portrait tutor films.
  bool get _square => widget.film == null && (widget.exercise?.film?.asset ?? false);

  @override
  void initState() {
    super.initState();
    final rel = _rel;
    final network = widget.film == null ? widget.exercise?.film : null;
    if (rel == null && (network == null || network.asset)) return;
    final c = openFilm(rel: rel, network: rel == null ? network!.src : null);
    _c = c;
    c.setVolume(0);
    c.setLooping(true);
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
    if (widget.playing) {
      c.play();
    } else {
      c.pause();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _video(VideoPlayerController c, BoxFit fit, Alignment alignment) => FittedBox(
    fit: fit,
    alignment: alignment,
    child: SizedBox.fromSize(size: filmBox(c, square: _square), child: VideoPlayer(c)),
  );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (widget.contain) return _contained(c);
    return ColoredBox(
      color: C.sand,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EImage(_poster),
          if (c != null && _ready)
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 500),
              child: ClipRect(child: _video(c, BoxFit.cover, widget.alignment)),
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
                              child: Image.asset(_poster),
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
                    Image.asset(_poster, fit: BoxFit.cover),
                    if (c != null && _ready) _video(c, BoxFit.cover, Alignment.center),
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
