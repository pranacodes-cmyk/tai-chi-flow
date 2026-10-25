import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import 'tokens.dart';

/// Typography matching the web utilities (display-xl, display-lg, display-md, title, eyebrow, serif-accent).
class T {
  T._();
  static const family = 'PlusJakartaSans';
  static const serif = 'InstrumentSerif';

  static const displayXl = TextStyle(
    fontFamily: family,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.02,
    letterSpacing: -1.4,
    color: C.ink,
  );
  static const displayLg = TextStyle(
    fontFamily: family,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.06,
    letterSpacing: -0.96,
    color: C.ink,
  );
  static const displayMd = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.12,
    letterSpacing: -0.6,
    color: C.ink,
  );
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.27,
    color: C.ink,
  );
  static const eyebrow = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.54,
    color: C.muted,
  );
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: C.ink,
  );
  static const bodySm = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: C.ink,
  );
  static const label = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    color: C.ink,
  );
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: C.muted,
  );
  static const tiny = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: C.muted,
  );
  static const _serifAccent = TextStyle(
    fontFamily: serif,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    color: C.ink,
  );

  /// Japanese has no italic tradition (the system font would be slanted artificially), so the
  /// accent keeps its weight and colour but stands upright in Japanese.
  static const _serifAccentUpright = TextStyle(
    fontFamily: serif,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: C.ink,
  );

  static TextStyle get serifAccent =>
      appLang == 'ja' ? _serifAccentUpright : _serifAccent;

  static const tabular = [FontFeature.tabularFigures()];
}

extension TextStyleX on TextStyle {
  TextStyle c(Color color) => copyWith(color: color);
  TextStyle s(double size) => copyWith(fontSize: size);
  TextStyle w(FontWeight weight) => copyWith(fontWeight: weight);
  TextStyle get tab => copyWith(fontFeatures: T.tabular);
}
