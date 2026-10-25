// App text in the person's language. Every on-screen string is a key in the shared UI catalogue
// (scripts/content/i18n/ui.en.json → `ui` in each generated content file), translated per language
// by scripts/translate.ts. Mirrors src/lib/i18n.ts (tests assert identical output).
//
// Messages use `{name}` placeholders, ICU-style plurals and selects:
//   "{n, plural, one {# day} other {# days}}"   "{hasName, select, yes {{name}, your…} other {Your…}}"

import 'dart:ui' show PlatformDispatcher;

/// The device's preferred languages, most preferred first (BCP-47 tags).
List<String> deviceLanguageTags() => [
  for (final l in PlatformDispatcher.instance.locales) l.toLanguageTag(),
];

String _lang = 'en';
Map<String, String> _ui = const {};

/// Point the translator at a language's UI catalogue (called when its content loads).
void setI18n(String lang, Map<String, String> ui) {
  _lang = lang;
  _ui = ui;
}

/// Active app language code ("en", "de", "ja"…).
String get appLang => _lang;

/// Locale for intl date/number formatting.
String get appLocale => _lang == 'pt' ? 'pt_BR' : _lang;

/// CLDR plural category for whole numbers in the shipped languages.
String pluralCategory(String lang, num n) {
  final i = n.abs().floor();
  final whole = i == n.abs();
  switch (lang) {
    case 'ja':
      return 'other';
    case 'fr':
    case 'pt':
      return i == 0 || i == 1 ? 'one' : 'other';
    default:
      return whole && i == 1 ? 'one' : 'other';
  }
}

int _closing(String s, int open) {
  var depth = 0;
  for (var k = open; k < s.length; k++) {
    if (s[k] == '{') {
      depth++;
    } else if (s[k] == '}' && --depth == 0) {
      return k;
    }
  }
  return -1;
}

final _option = RegExp(r'^\s*(=\d+|zero|one|two|few|many|other)\s*\{');
final _pluralHead = RegExp(r'^\s*(\w+)\s*,\s*(plural|select)\s*,([\s\S]*)$');
final _anyOption = RegExp(r'^\s*(=\d+|[\w-]+)\s*\{');

String _select(String body, String value, String lang, Map<String, Object?> args) {
  final options = <String, String>{};
  var k = 0;
  while (k < body.length) {
    final m = _anyOption.firstMatch(body.substring(k));
    if (m == null) break;
    final open = k + m.group(0)!.length - 1;
    final end = _closing(body, open);
    if (end < 0) break;
    options[m.group(1)!] = body.substring(open + 1, end);
    k = end + 1;
  }
  return _format(options[value] ?? options['other'] ?? '', args, lang);
}

String _plural(String body, num value, String lang, Map<String, Object?> args) {
  final options = <String, String>{};
  var k = 0;
  while (k < body.length) {
    final m = _option.firstMatch(body.substring(k));
    if (m == null) break;
    final open = k + m.group(0)!.length - 1;
    final end = _closing(body, open);
    if (end < 0) break;
    options[m.group(1)!] = body.substring(open + 1, end);
    k = end + 1;
  }
  final whole = value == value.roundToDouble() ? value.toInt() : value;
  final chosen = options['=$whole'] ??
      options[pluralCategory(lang, value)] ??
      options['other'] ??
      '';
  return _format(chosen.replaceAll('#', '$whole'), args, lang);
}

String _format(String msg, Map<String, Object?> args, String lang) {
  final out = StringBuffer();
  var k = 0;
  while (k < msg.length) {
    final open = msg.indexOf('{', k);
    if (open < 0) {
      out.write(msg.substring(k));
      break;
    }
    out.write(msg.substring(k, open));
    final end = _closing(msg, open);
    if (end < 0) {
      out.write(msg.substring(open));
      break;
    }
    final inner = msg.substring(open + 1, end);
    final pm = _pluralHead.firstMatch(inner);
    if (pm != null && pm.group(2) == 'plural') {
      final raw = args[pm.group(1)!];
      final n = raw is num ? raw : num.tryParse('${raw ?? 0}') ?? 0;
      out.write(_plural(pm.group(3)!, n, lang, args));
    } else if (pm != null) {
      out.write(_select(pm.group(3)!, '${args[pm.group(1)!] ?? 'other'}', lang, args));
    } else {
      final name = inner.trim();
      final v = args[name];
      out.write(v == null ? '{$name}' : '$v');
    }
    k = end + 1;
  }
  return out.toString();
}

/// Format an ICU-lite message with arguments in a given language.
/// Argument names a message uses — simple `{name}` placeholders and plural/select arguments,
/// searched inside every branch (sorted, unique). Mirrors web `messageArgs`.
List<String> messageArgs(String msg) {
  final names = <String>{};
  void walk(String m) {
    var k = 0;
    while (k < m.length) {
      final open = m.indexOf('{', k);
      if (open < 0) return;
      final end = _closing(m, open);
      if (end < 0) return;
      final inner = m.substring(open + 1, end);
      final pm = _pluralHead.firstMatch(inner);
      if (pm != null) {
        names.add(pm.group(1)!);
        var j = 0;
        final body = pm.group(3)!;
        while (j < body.length) {
          final om = _anyOption.firstMatch(body.substring(j));
          if (om == null) break;
          final o = j + om.group(0)!.length - 1;
          final e = _closing(body, o);
          if (e < 0) break;
          walk(body.substring(o + 1, e));
          j = e + 1;
        }
      } else {
        names.add(inner.trim());
      }
      k = end + 1;
    }
  }

  walk(msg);
  return names.toList()..sort();
}

String formatMessage(
  String msg, [
  Map<String, Object?> args = const {},
  String? lang,
]) => _format(msg, args, lang ?? _lang);

/// The localized UI string for [key], with `{placeholders}` and plurals filled from [args].
String tr(String key, [Map<String, Object?> args = const {}]) {
  final msg = _ui[key];
  return msg == null ? key : _format(msg, args, _lang);
}

/// Localized label for a content tag kept in English as a stable id (shelves, focus areas, levels…).
String trTag(String tag) => _ui['tag.$tag'] ?? tag;

/// Localized list of words split from a comma-separated UI string (e.g. weekday letters).
List<String> trList(String key) =>
    tr(key).split(',').map((s) => s.trim()).toList();

/// A UI template split around its simple `{placeholders}`: literal text has a null name, so callers
/// can render placeholders as widgets (links) in whatever order the language puts them.
List<({String text, String? name})> trParts(String key) {
  final msg = _ui[key] ?? key;
  final out = <({String text, String? name})>[];
  var last = 0;
  for (final m in RegExp(r'\{(\w+)\}').allMatches(msg)) {
    if (m.start > last) out.add((text: msg.substring(last, m.start), name: null));
    out.add((text: '', name: m.group(1)));
    last = m.end;
  }
  if (last < msg.length) out.add((text: msg.substring(last), name: null));
  return out;
}
