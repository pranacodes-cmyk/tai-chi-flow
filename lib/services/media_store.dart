import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../logic/lesson_media.dart';

/// Lesson films and coach clips downloaded from the public R2 media server and kept on the
/// phone for offline replay (web `src/lib/media-store.ts`). Onboarding/UI media stays bundled.
/// Lookup order everywhere: downloaded file → bundled asset → stream from the server.
class MediaStore {
  MediaStore._();
  static Directory? _dir;
  static Set<String> _bundled = const {};
  static Map<String, String> _bundledRev = const {};
  static Map<String, String> _rev = const {};

  /// Film fingerprints of the content bundled in this build and of the content in use (a newer
  /// published update may name re-made films), set by `Content.load`.
  static void setRevisions({
    required Map<String, String> bundled,
    required Map<String, String> active,
  }) {
    _bundledRev = bundled;
    _rev = active;
  }

  static String? _want(String path) => filmRev(_rev, path);

  static Future<void> init() async {
    try {
      final support = await getApplicationSupportDirectory();
      _dir = Directory('${support.path}/media/v1');
      await _dir!.create(recursive: true);
    } catch (e) {
      debugPrint('TaiChi Flow media dir: $e');
    }
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _bundled = manifest.listAssets().toSet();
    } catch (e) {
      debugPrint('TaiChi Flow asset manifest: $e');
    }
  }

  /// `video/x.mp4` → bundled asset path `assets/video/x.mp4` when it ships in the app and is
  /// still the film the content wants (a re-made film is downloaded instead).
  static bool isBundled(String path) =>
      _bundled.contains('assets/$path') &&
      sameMedia(_want(path), filmRev(_bundledRev, path));

  static String url(String path) => mediaUrl(path, _want(path));

  /// The downloaded copy when it is still the film the content wants, or null.
  static File? cached(String path) {
    final d = _dir;
    if (d == null) return null;
    final f = File('${d.path}/$path');
    if (!f.existsSync()) return null;
    final want = _want(path);
    if (want == null) return f;
    final tag = File('${f.path}.rev');
    final have = tag.existsSync() ? tag.readAsStringSync().trim() : null;
    return sameMedia(want, have) ? f : null;
  }

  /// Paths that are neither bundled nor downloaded yet.
  static List<String> missing(Iterable<String> paths) =>
      [for (final p in paths) if (!isBundled(p) && cached(p) == null) p];

  /// Downloads [paths] (4 at a time) with real per-file progress. Throws on the first failure
  /// after one retry per file; files already finished stay saved, so a retry resumes.
  static Future<void> download(
    List<String> paths, {
    required void Function(int done, int total) onProgress,
    required bool Function() cancelled,
  }) async {
    final d = _dir;
    if (d == null) throw StateError('media storage unavailable');
    final client = http.Client();
    var done = 0, next = 0;
    onProgress(0, paths.length);
    Future<void> worker() async {
      while (next < paths.length) {
        if (cancelled()) return;
        final p = paths[next++];
        await _fetch(client, d, p);
        done++;
        if (!cancelled()) onProgress(done, paths.length);
      }
    }

    try {
      await Future.wait([for (var i = 0; i < 8; i++) worker()]);
    } finally {
      client.close();
    }
  }

  static Future<void> _fetch(http.Client client, Directory d, String p) async {
    Object? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await client
            .get(Uri.parse(url(p)))
            .timeout(const Duration(seconds: 45));
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
          throw HttpException('HTTP ${res.statusCode} for $p');
        }
        final f = File('${d.path}/$p');
        await f.parent.create(recursive: true);
        final tmp = File('${f.path}.part');
        await tmp.writeAsBytes(res.bodyBytes, flush: true);
        await tmp.rename(f.path);
        // remember which version this is, so a later re-made film is fetched again
        final want = _want(p);
        final tag = File('${f.path}.rev');
        if (want != null) {
          await tag.writeAsString(want, flush: true);
        } else if (tag.existsSync()) {
          await tag.delete();
        }
        return;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? HttpException('download failed: $p');
  }

  static final Set<String> _packsStarted = {};

  /// Only English onboarding/UI/breath clips ship in the app; any other language downloads its
  /// small clip pack (`assets/data/voice-packs.json`, ~2.7 MB) once in the background when it is
  /// chosen. Until a clip is saved it streams, and offline it falls back to the device voice.
  static Future<void> prefetchVoicePack(String lang) async {
    if (lang == 'en' || !_packsStarted.add(lang)) return;
    try {
      final packs = jsonDecode(
        await rootBundle.loadString('assets/data/voice-packs.json'),
      ) as Map<String, dynamic>;
      final keys = (packs[lang] as List? ?? const []).cast<String>();
      final todo = missing([for (final k in keys) voicePath(k)]);
      if (todo.isEmpty) return;
      await download(todo, onProgress: (a, b) {}, cancelled: () => false);
    } catch (e) {
      _packsStarted.remove(lang); // retried on the next language load or launch
      debugPrint('TaiChi Flow voice pack $lang: $e');
    }
  }

  /// Saves a streamed file in the background so it plays offline next time (best effort).
  static void cacheInBackground(String path) {
    final d = _dir;
    if (d == null || cached(path) != null || isBundled(path)) return;
    final client = http.Client();
    unawaited(
      _fetch(client, d, path).catchError((_) {}).whenComplete(client.close),
    );
  }
}
