import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../logic/logic.dart';

/// Over-the-air content (courses, lessons, order, text, voice lists) published to the public R2
/// bucket by `scripts/media/publish-content.py` (web mirror `src/lib/content-updates.ts`).
///
/// `content/manifest.json` = `{rev, schema, files: {<lang>: {path, bytes}}}`. A check downloads
/// the app language's file only when [shouldUseRemoteContent] says it is newer, validates it
/// (size, JSON, matching revision) and saves it; [Content.load] adopts it on the next launch, so
/// nothing changes under someone mid-session. Any failure keeps the bundled content.
class ContentUpdates {
  ContentUpdates._();

  static const String base =
      'https://pub-6b6ccbaa2b5946dd851b43b1f1219507.r2.dev/content';

  static Future<Directory?> _dir() async {
    try {
      final s = await getApplicationSupportDirectory();
      final d = Directory('${s.path}/content');
      await d.create(recursive: true);
      return d;
    } catch (_) {
      return null;
    }
  }

  /// Saved remote content for [lang] when it is newer than [bundledRev]; otherwise null.
  static Future<Map<String, dynamic>?> saved(String lang, int bundledRev) async {
    try {
      final d = await _dir();
      final f = File('${d?.path}/$lang.json');
      if (d == null || !f.existsSync()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final rev = (j['contentRev'] as num?)?.toInt();
      final schema = (j['contentSchema'] as num?)?.toInt() ?? 1;
      return shouldUseRemoteContent(bundledRev, rev, schema) ? j : null;
    } catch (e) {
      debugPrint('TaiChi Flow saved content: $e');
      return null;
    }
  }

  /// Downloads a newer published revision for [lang] in the background.
  static Future<void> check(String lang, int bundledRev) async {
    final d = await _dir();
    if (d == null) return;
    final client = http.Client();
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final res = await client
          .get(Uri.parse('$base/manifest.json?t=$now'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final rev = (m['rev'] as num?)?.toInt();
      final schema = (m['schema'] as num?)?.toInt();
      if (!shouldUseRemoteContent(bundledRev, rev, schema)) return;
      final file = (m['files'] as Map?)?[lang] as Map?;
      if (file == null) return;
      final have = await saved(lang, bundledRev);
      if (have != null && (have['contentRev'] as num?)?.toInt() == rev) return;
      final body = await client
          .get(Uri.parse('$base/${file['path']}'))
          .timeout(const Duration(seconds: 60));
      if (body.statusCode != 200) return;
      if (file['bytes'] != null && body.bodyBytes.length != file['bytes']) return;
      final j = jsonDecode(utf8.decode(body.bodyBytes)) as Map<String, dynamic>;
      if ((j['contentRev'] as num?)?.toInt() != rev || j['plans'] is! List) return;
      final tmp = File('${d.path}/$lang.json.part');
      await tmp.writeAsBytes(body.bodyBytes, flush: true);
      await tmp.rename('${d.path}/$lang.json');
      debugPrint('TaiChi Flow content r$rev saved for $lang');
    } catch (e) {
      debugPrint('TaiChi Flow content check: $e');
    } finally {
      client.close();
    }
  }
}
