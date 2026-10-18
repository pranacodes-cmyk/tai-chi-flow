import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/content.dart';

/// Ambient loops, sound effects and voice guidance — mirrors src/lib/audio.ts.
class Ambient {
  Ambient._();
  static final AudioPlayer _player = AudioPlayer(playerId: 'ambient');
  static String _key = '';
  static bool _playing = false;
  static Timer? _fade;
  static double _volume = 0;

  static Future<void> _fadeTo(double target, {int ms = 600, VoidCallback? then}) async {
    _fade?.cancel();
    final start = _volume;
    const steps = 15;
    var i = 0;
    final c = Completer<void>();
    _fade = Timer.periodic(Duration(milliseconds: ms ~/ steps), (t) {
      i++;
      _volume = (start + (target - start) * i / steps).clamp(0.0, 1.0);
      _player.setVolume(_volume);
      if (i >= steps) {
        t.cancel();
        then?.call();
        if (!c.isCompleted) c.complete();
      }
    });
    return c.future;
  }

  static Future<void> play(String key, [double volume = 0.5]) async {
    try {
      if (_key != key) {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.loop);
        _volume = 0;
        await _player.setVolume(0);
        await _player.play(AssetSource(audioAsset(key)));
        _key = key;
      } else if (!_playing) {
        await _player.resume();
      }
      _playing = true;
      unawaited(_fadeTo(volume));
    } catch (e) {
      debugPrint('Enso ambient error: $e');
    }
  }

  static void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _player.setVolume(_volume);
  }

  static void pause() {
    if (!_playing) return;
    _playing = false;
    _fadeTo(0, ms: 400, then: () => _player.pause());
  }

  static void stop() {
    if (_key.isEmpty) return;
    _playing = false;
    _fadeTo(0, ms: 500, then: () => _player.stop());
    _key = '';
  }

  static bool isPlaying([String? key]) => _playing && (key == null || key == _key);
}

class Sfx {
  Sfx._();
  static final _pool = <String, AudioPlayer>{};

  static Future<void> play(String key, [double volume = 0.7]) async {
    try {
      final p = _pool.putIfAbsent(key, () => AudioPlayer(playerId: 'sfx-$key')..setReleaseMode(ReleaseMode.stop));
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource(audioAsset(key)), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Enso sfx error: $e');
    }
  }
}

class Voice {
  Voice._();
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
      final voices = await _tts.getVoices;
      if (voices is List) {
        final en = voices.whereType<Map>().where((v) => '${v['locale']}'.toLowerCase().startsWith('en')).toList();
        final pick = en.where((v) => RegExp('female|en-us-x-tpf|en-gb-x-gba|sfg', caseSensitive: false).hasMatch('${v['name']}')).firstOrNull ?? en.firstOrNull;
        if (pick != null) await _tts.setVoice({'name': '${pick['name']}', 'locale': '${pick['locale']}'});
      }
    } catch (e) {
      debugPrint('Enso tts init: $e');
    }
  }

  /// [rate] uses the web scale (1.0 = natural). Android TTS treats 0.5 as natural.
  static Future<void> speak(String text, [double rate = 0.95]) async {
    await _init();
    try {
      await _tts.stop();
      await _tts.setSpeechRate((rate * 0.5).clamp(0.2, 0.8));
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Enso tts: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

class Haptics {
  Haptics._();
  static bool enabled = true;
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
