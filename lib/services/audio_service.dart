import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/content.dart';
import '../i18n/i18n.dart';
import '../logic/coach.dart';
import '../logic/logic.dart' show fallbackVoiceLocales, fallbackVoiceRank;

/// Every player mixes with the others instead of taking Android audio focus.
/// With the plugin default (focus "gain") the coach's voice clip stole focus from the
/// music player, which paused it — so music only sometimes kept playing.
class AudioSetup {
  AudioSetup._();
  static final AudioContext context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();
  static bool _globalDone = false;
  static final Set<String> _configured = {};

  static Future<void> ensure(AudioPlayer player) async {
    try {
      if (!_globalDone) {
        _globalDone = true;
        await AudioPlayer.global.setAudioContext(context);
      }
      if (_configured.add(player.playerId)) {
        await player.setAudioContext(context);
      }
    } catch (e) {
      debugPrint('TaiChi Flow audio context: $e');
    }
  }
}

/// Ambient loops, sound effects and voice guidance — mirrors src/lib/audio.ts.
class Ambient {
  Ambient._();
  static final AudioPlayer _player = AudioPlayer(playerId: 'ambient');

  /// Track currently loaded into the player (may still be fading out after stop()).
  static String _loaded = '';

  /// Track the app wants (web `musicKey`).
  static String _key = '';

  /// What the app wants right now; the player may lag behind while it fades.
  static bool _playing = false;

  /// Bumped by every play / pause / stop so a stale fade or a slow async call
  /// can never undo a newer request (the old race that silenced the music).
  static int _gen = 0;
  static Future<void> _chain = Future.value();

  /// Observable state (web `ambient.subscribe`) for the "now playing" pill.
  static final ValueNotifier<({String key, bool playing})> state =
      ValueNotifier((key: '', playing: false));
  static void _emit() => state.value = (key: _key, playing: _playing);
  static Timer? _fade;
  static double _volume = 0;
  static double _target = 0.5;
  static bool _ducked = false;
  static const double _duck = 0.35;

  /// Player calls run one after another, never interleaved.
  static Future<void> _serial(Future<void> Function() op) {
    final next = _chain.then((_) => op()).catchError((Object e) {
      debugPrint('TaiChi Flow ambient error: $e');
    });
    _chain = next;
    return next;
  }

  static void _cancelFade() {
    _fade?.cancel();
    _fade = null;
  }

  static void _fadeTo(double target, {int ms = 600, VoidCallback? then}) {
    _cancelFade();
    final start = _volume;
    const steps = 15;
    var i = 0;
    _fade = Timer.periodic(Duration(milliseconds: ms ~/ steps), (t) {
      i++;
      _volume = (start + (target - start) * i / steps).clamp(0.0, 1.0);
      _player.setVolume(_volume);
      if (i >= steps) {
        t.cancel();
        if (identical(_fade, t)) _fade = null;
        then?.call();
      }
    });
  }

  static Future<void> play(String key, [double volume = 0.5]) {
    final g = ++_gen;
    _key = key;
    _target = volume;
    _playing = true;
    _cancelFade(); // a pending pause/stop fade must not silence this play
    _emit();
    return _serial(() async {
      if (g != _gen) return;
      await AudioSetup.ensure(_player);
      if (_loaded != key) {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.loop);
        _volume = 0;
        await _player.setVolume(0);
        await _player.setSource(AssetSource(audioAsset(key)));
        _loaded = key;
      }
      if (g != _gen) return;
      await _player.resume();
      if (g != _gen) return;
      _fadeTo(_ducked ? volume * _duck : volume);
    });
  }

  static void setVolume(double v) {
    _target = v.clamp(0.0, 1.0);
    if (!_playing) return;
    _cancelFade();
    _volume = _ducked ? _target * _duck : _target;
    _player.setVolume(_volume);
  }

  static void duck(bool on) {
    if (on == _ducked) return;
    _ducked = on;
    if (_playing) {
      _fadeTo(on ? _target * _duck : _target, ms: on ? 250 : 700);
    }
  }

  static void pause() {
    final g = ++_gen;
    if (!_playing) return;
    _playing = false;
    _emit();
    _fadeTo(
      0,
      ms: 400,
      then: () {
        if (g == _gen) _serial(() => _player.pause());
      },
    );
  }

  static void stop() {
    final g = ++_gen;
    final wasActive = _playing || _key.isNotEmpty;
    _playing = false;
    _key = '';
    _emit();
    if (!wasActive) return;
    _fadeTo(
      0,
      ms: 500,
      then: () {
        if (g != _gen) return;
        _serial(() async {
          if (g != _gen) return;
          await _player.stop();
          _loaded = '';
        });
      },
    );
  }

  static bool isPlaying([String? key]) =>
      _playing && (key == null || key == _key);
}

class Sfx {
  Sfx._();
  static final _pool = <String, AudioPlayer>{};

  static Future<void> play(String key, [double volume = 0.7]) async {
    try {
      final p = _pool.putIfAbsent(
        key,
        () =>
            AudioPlayer(playerId: 'sfx-$key')..setReleaseMode(ReleaseMode.stop),
      );
      await AudioSetup.ensure(p);
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource(audioAsset(key)), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('TaiChi Flow sfx error: $e');
    }
  }
}

class Voice {
  Voice._();
  static final AudioPlayer _player = AudioPlayer(playerId: 'voice');
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;
  static StreamSubscription<void>? _sub;
  static final ValueNotifier<bool> speaking = ValueNotifier(false);
  static List<String> _queue = [];
  static bool _busy = false;
  static int _token = 0;
  static double _rate = 0.95;
  static VoidCallback? _onDone;

  static Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await AudioSetup.ensure(_player);
      await _player.setReleaseMode(ReleaseMode.stop);
      _sub = _player.onPlayerComplete.listen((_) => _next(_token));
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('TaiChi Flow voice init: $e');
    }
  }

  static String? _voiceLang;

  /// Device voice for lines without a clip, in the app language. English uses only US, then UK
  /// voices: a regional default (e.g. Indian or Australian English) would read the coach's lines
  /// in an accent the app never uses (web `pickVoice`, rule in `fallbackVoiceRank`).
  static Future<void> _pickVoice() async {
    final lang = appLang;
    if (_voiceLang == lang) return;
    _voiceLang = lang;
    try {
      await _tts.setLanguage(fallbackVoiceLocales(lang).first);
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      final ok = [
        for (final v in voices.whereType<Map>())
          if (fallbackVoiceRank(lang, '${v['locale']}') != null) v,
      ]..sort(
          (a, b) =>
              fallbackVoiceRank(lang, '${a['locale']}')! -
              fallbackVoiceRank(lang, '${b['locale']}')!,
        );
      final pick =
          ok
              .where(
                (v) => RegExp(
                  'female|en-us-x-tpf|en-gb-x-gba|sfg',
                  caseSensitive: false,
                ).hasMatch('${v['name']}'),
              )
              .firstOrNull ??
          ok.firstOrNull;
      if (pick != null) {
        await _tts.setVoice({
          'name': '${pick['name']}',
          'locale': '${pick['locale']}',
        });
      }
    } catch (e) {
      debugPrint('TaiChi Flow voice language: $e');
    }
  }

  static bool hasClip(String line) => Content.i.voice.contains(voiceKey(line));

  static Future<void> say(
    List<String> lines, {
    bool interrupt = true,
    double rate = 0.95,
    VoidCallback? onDone,
  }) async {
    final clean = lines.where((l) => l.trim().isNotEmpty).toList();
    if (clean.isEmpty) return;
    await _init();
    if (!interrupt && _busy) {
      _queue = clean;
      _rate = rate;
      if (onDone != null) _onDone = onDone;
      return;
    }
    await stop();
    _queue = clean;
    _rate = rate;
    _onDone = onDone;
    _next(_token);
  }

  static void _finish() {
    _busy = false;
    speaking.value = false;
    Ambient.duck(false);
    final cb = _onDone;
    _onDone = null;
    cb?.call();
  }

  static Future<void> _next(int t) async {
    if (t != _token) return;
    if (_queue.isEmpty) return _finish();
    final line = _queue.removeAt(0);
    _busy = true;
    speaking.value = true;
    Ambient.duck(true);
    final key = voiceKey(line);
    if (!Content.i.voice.contains(key)) return _fallback(line, t);
    try {
      await _player.setPlaybackRate((_rate / 0.95).clamp(0.8, 1.25));
      await _player.play(AssetSource(voiceAsset(key)), volume: 1.0);
    } catch (e) {
      debugPrint('TaiChi Flow voice clip: $e');
      if (t == _token) await _fallback(line, t);
    }
  }

  static Future<void> _fallback(String line, int t) async {
    try {
      _tts.setCompletionHandler(() => _next(t));
      _tts.setCancelHandler(() {});
      _tts.setErrorHandler((_) => _next(t));
      await _pickVoice();
      await _tts.setSpeechRate((_rate * 0.5).clamp(0.2, 0.8));
      await _tts.speak(line);
    } catch (e) {
      debugPrint('TaiChi Flow tts: $e');
      _next(t);
    }
  }

  static Future<void> speak(String text, [double rate = 0.95]) =>
      say([text], rate: rate);
  static Future<void> speakParts(
    List<String> parts,
    VoidCallback onDone, [
    double rate = 0.95,
  ]) => say(parts, rate: rate, onDone: onDone);
  static void clearHandlers() => _onDone = null;

  static Future<void> stop() async {
    _token++;
    _queue = [];
    _onDone = null;
    final wasBusy = _busy;
    _busy = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      _tts.setCompletionHandler(() {});
      await _tts.stop();
    } catch (_) {}
    if (wasBusy) Ambient.duck(false);
    speaking.value = false;
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
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
