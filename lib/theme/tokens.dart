import 'package:flutter/material.dart';

/// TaiChi Flow design tokens. Every value mirrors src/styles.css — keep both in sync.
class C {
  C._();
  static const cream = Color(0xFFF7F3EC);
  static const ivory = Color(0xFFFCFAF6);
  static const sand = Color(0xFFEFE6D8);
  static const sandDeep = Color(0xFFE4D6C1);
  static const jade = Color(0xFF3F7A5C);
  static const jadeDeep = Color(0xFF24493A);
  static const jadeSoft = Color(0xFFDCE8DF);
  static const sage = Color(0xFF9DB8A2);
  static const ink = Color(0xFF1D2320);
  static const muted = Color(0xFF727A74);
  static const line = Color(0xFFE7DFD2);
  static const terracotta = Color(0xFFD27D56);
  static const terracottaSoft = Color(0xFFF6E3D6);
  static const gold = Color(0xFFC9A24C);
  static const goldSoft = Color(0xFFF4E9CC);
  static const forest = Color(0xFF0F1713);
  static const forest2 = Color(0xFF16221C);
  static const danger = Color(0xFFC2543F);
  static const stage = Color(0xFFE7DED0);

  /// Studio wall colour of the demo films (web `--studio`).
  static const studio = Color(0xFFD8CFC1);
}

class G {
  G._();
  static const jade = LinearGradient(
    begin: Alignment(-0.77, -0.64),
    end: Alignment(0.77, 0.64),
    colors: [Color(0xFF51906D), C.jadeDeep],
  );
  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDDB966), Color(0xFFBD853F)],
  );
  static const ember = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5955D), Color(0xFFC76749)],
  );
  static const forest = RadialGradient(
    center: Alignment(0, -1),
    radius: 1.3,
    colors: [Color(0xFF20392C), C.forest],
    stops: [0, 0.6],
  );
  static final scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFF141E19).withValues(alpha: 0),
      const Color(0xFF141E19).withValues(alpha: 0.15),
      const Color(0xFF111A15).withValues(alpha: 0.82),
    ],
    stops: const [0, 0.4, 1],
  );
  static final heroTopBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFF111A15).withValues(alpha: 0.35),
      const Color(0xFF111A15).withValues(alpha: 0),
      const Color(0xFF111A15).withValues(alpha: 0.85),
    ],
    stops: const [0, 0.3, 1],
  );
}

class S {
  S._();
  static final soft = [
    BoxShadow(
      color: C.ink.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: C.ink.withValues(alpha: 0.10),
      blurRadius: 20,
      spreadRadius: -8,
      offset: const Offset(0, 6),
    ),
  ];
  static final card = [
    BoxShadow(
      color: C.ink.withValues(alpha: 0.03),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF2F3D33).withValues(alpha: 0.22),
      blurRadius: 32,
      spreadRadius: -14,
      offset: const Offset(0, 12),
    ),
  ];
  static final float = [
    BoxShadow(
      color: C.jadeDeep.withValues(alpha: 0.45),
      blurRadius: 60,
      spreadRadius: -24,
      offset: const Offset(0, 24),
    ),
  ];
  static final glow = [
    BoxShadow(
      color: C.jade.withValues(alpha: 0.55),
      blurRadius: 30,
      spreadRadius: -8,
      offset: const Offset(0, 10),
    ),
  ];
  static final goldGlow = [
    BoxShadow(
      color: C.gold.withValues(alpha: 0.7),
      blurRadius: 30,
      spreadRadius: -10,
      offset: const Offset(0, 12),
    ),
  ];
}

class R {
  R._();
  static const sm = 20.0;
  static const md = 24.0;
  static const lg = 28.0;
  static const xl = 32.0;
  static const xxl = 34.0;
}

/// Motion curve matching the web's cubic-bezier(0.22, 1, 0.36, 1).
const kEase = Cubic(0.22, 1, 0.36, 1);
