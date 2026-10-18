import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/audio_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';

/// Scale-on-press wrapper (web `.press`: active:scale-0.97).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = true, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                if (widget.haptic) Haptics.select();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Duration(milliseconds: _down ? 90 : 260),
          curve: kEase,
          child: widget.child,
        ),
      ),
    );
  }
}

enum BtnVariant { primary, secondary, ghost, glass, light, gold, ivory }

enum BtnSize { lg, md, sm }

class EnsoButton extends StatelessWidget {
  const EnsoButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = BtnVariant.primary,
    this.size = BtnSize.lg,
    this.icon,
    this.trailing,
    this.loading = false,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onTap;
  final BtnVariant variant;
  final BtnSize size;
  final IconData? icon;
  final IconData? trailing;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final h = switch (size) { BtnSize.lg => 56.0, BtnSize.md => 48.0, BtnSize.sm => 36.0 };
    final fs = switch (size) { BtnSize.lg => 17.0, BtnSize.md => 15.0, BtnSize.sm => 13.0 };
    final pad = switch (size) { BtnSize.lg => 28.0, BtnSize.md => 20.0, BtnSize.sm => 16.0 };
    Gradient? gradient;
    Color? bg;
    Color fg = C.ink;
    List<BoxShadow>? shadow;
    switch (variant) {
      case BtnVariant.primary:
        gradient = G.jade;
        fg = C.ivory;
        shadow = S.glow;
      case BtnVariant.secondary:
        bg = C.sand;
      case BtnVariant.ghost:
        bg = Colors.transparent;
        fg = C.muted;
      case BtnVariant.glass:
        bg = C.forest.withValues(alpha: 0.35);
        fg = C.ivory;
      case BtnVariant.light:
        bg = C.ivory;
        shadow = S.soft;
      case BtnVariant.gold:
        gradient = G.gold;
        shadow = S.goldGlow;
      case BtnVariant.ivory:
        bg = C.ivory;
    }
    final disabled = onTap == null || loading;
    final content = loading
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: fs + 3, color: fg), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: T.label.copyWith(fontSize: fs, color: fg, fontWeight: FontWeight.w600, letterSpacing: -0.17))),
              if (trailing != null) ...[const SizedBox(width: 8), Icon(trailing, size: fs + 3, color: fg)],
            ],
          );
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Pressable(
        onTap: disabled ? null : onTap,
        child: Container(
          height: h,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: pad),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, gradient: gradient, borderRadius: BorderRadius.circular(h), boxShadow: shadow),
          child: content,
        ),
      ),
    );
  }
}

/// Image asset with soft fade-in (web `Img`).
class EImage extends StatelessWidget {
  const EImage(this.asset, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center});
  final String asset;
  final BoxFit fit;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 700), curve: Curves.easeOut, child: child);
      },
      errorBuilder: (_, _, _) => Container(color: C.sand),
    );
  }
}

/// Slow 18s zoom used on hero imagery (web .animate-ken-burns).
class KenBurns extends StatefulWidget {
  const KenBurns({super.key, required this.child, this.running = true});
  final Widget child;
  final bool running;
  @override
  State<KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<KenBurns> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));
  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant KenBurns old) {
    super.didUpdateWidget(old);
    if (widget.running && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.running && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(scale: 1.04 + 0.08 * t, child: Transform.translate(offset: Offset(-6 * t, -4 * t), child: child));
      },
      child: widget.child,
    );
  }
}

/// Fade + rise on first build (web `Reveal`).
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = 0, this.dy = 18});
  final Widget child;
  final double delay;
  final double dy;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: kEase);
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Opacity(opacity: a.value, child: Transform.translate(offset: Offset(0, widget.dy * (1 - a.value)), child: child)),
      child: widget.child,
    );
  }
}

/// Frosted glass surface.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 999, this.dark = true, this.padding, this.blur = 18});
  final Widget child;
  final double radius;
  final bool dark;
  final EdgeInsetsGeometry? padding;
  final double blur;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF141E19).withValues(alpha: 0.35) : C.ivory.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: dark ? C.ivory.withValues(alpha: 0.14) : C.ivory.withValues(alpha: 0.7), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Circular progress ring with optional centered child.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, this.size = 64, this.stroke = 6, this.track = C.sand, this.bar = C.jade, this.child});
  final double value;
  final double size;
  final double stroke;
  final Color track;
  final Color bar;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (_, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, stroke, track, bar),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.track, this.bar);
  final double v, stroke;
  final Color track, bar;
  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p..color = track);
    if (v > 0) canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * v, false, p..color = bar);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.v != v || o.bar != bar || o.track != track;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: T.title.s(20))),
          if (action != null)
            Pressable(onTap: onAction, child: Text(action!, style: T.label.copyWith(fontSize: 14, color: C.jade))),
        ],
      ),
    );
  }
}

enum Tone { light, dark, sand }

class CircleBtn extends StatelessWidget {
  const CircleBtn({super.key, required this.icon, this.onTap, this.tone = Tone.light, this.label, this.size = 44, this.iconColor, this.iconSize = 20});
  final IconData icon;
  final VoidCallback? onTap;
  final Tone tone;
  final String? label;
  final double size;
  final Color? iconColor;
  final double iconSize;
  @override
  Widget build(BuildContext context) {
    final iconW = Icon(icon, size: iconSize, color: iconColor ?? (tone == Tone.dark ? C.ivory : C.ink));
    final Widget body = switch (tone) {
      Tone.dark => Glass(radius: size, child: SizedBox(width: size, height: size, child: Center(child: iconW))),
      Tone.light => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: C.ivory.withValues(alpha: 0.92), shape: BoxShape.circle, boxShadow: S.soft),
          child: Center(child: iconW),
        ),
      Tone.sand => Container(width: size, height: size, decoration: const BoxDecoration(color: C.sand, shape: BoxShape.circle), child: Center(child: iconW)),
    };
    return Pressable(onTap: onTap, semanticLabel: label, child: body);
  }
}

class BackBtn extends StatelessWidget {
  const BackBtn({super.key, this.tone = Tone.light, this.onTap});
  final Tone tone;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return CircleBtn(
      icon: LucideIcons.chevronLeft,
      tone: tone,
      label: 'Back',
      onTap: onTap ?? () => context.canPop() ? context.pop() : context.go('/'),
    );
  }
}

class ChipPill extends StatelessWidget {
  const ChipPill({super.key, required this.label, this.active = false, this.onTap, this.height = 40});
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final double height;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? C.ink : C.ivory, borderRadius: BorderRadius.circular(height), boxShadow: active ? null : S.soft),
        child: Text(label, style: T.label.copyWith(fontSize: 14, color: active ? C.ivory : C.ink.withValues(alpha: 0.8))),
      ),
    );
  }
}

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.label = 'PLUS'});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(gradient: G.gold, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.crown, size: 12, color: C.ink),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontFamily: T.family, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: C.ink)),
      ]),
    );
  }
}

/// Larger gold pill for hero headers: "Enso Plus" or "First 3 days free".
class PlusChip extends StatelessWidget {
  const PlusChip({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(gradient: G.gold, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.crown, size: 14, color: C.ink),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: T.family, fontSize: 12, fontWeight: FontWeight.w700, color: C.ink)),
      ]),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = C.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: T.eyebrow.c(color));
}

class Dot extends StatelessWidget {
  const Dot({super.key, this.color = C.ivory});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 4,
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.5), shape: BoxShape.circle),
      );
}

/// White card with soft shadow.
class ECard extends StatelessWidget {
  const ECard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 30, this.color = C.ivory, this.shadow, this.gradient});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: gradient == null ? color : null, gradient: gradient, borderRadius: BorderRadius.circular(radius), boxShadow: shadow ?? S.card),
      child: child,
    );
  }
}

/// Rounded image tile with clip.
class RoundedImage extends StatelessWidget {
  const RoundedImage(this.asset, {super.key, this.size = 64, this.radius = 16});
  final String asset;
  final double size;
  final double radius;
  @override
  Widget build(BuildContext context) {
    // exercise illustrations are full-body studio shots — zoom in so the pose reads at thumbnail size
    final zoom = asset.contains('/ex-');
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(color: C.sand, child: zoom ? Transform.scale(scale: 1.32, child: EImage(asset)) : EImage(asset)),
      ),
    );
  }
}

/// Bottom-pinned CTA with fade from background.
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.child, this.color = C.cream});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 32, 24, bottom + 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color, color.withValues(alpha: 0.95), color.withValues(alpha: 0)],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ContentIcon extends StatelessWidget {
  const ContentIcon(this.name, {super.key, this.size = 22, this.color});
  final String? name;
  final double size;
  final Color? color;

  static const map = <String, IconData>{
    'activity': LucideIcons.activity,
    'alert-circle': LucideIcons.circleAlert,
    'align-vertical': LucideIcons.alignVerticalJustifyCenter,
    'armchair': LucideIcons.armchair,
    'arrow-up': LucideIcons.arrowUp,
    'bike': LucideIcons.bike,
    'bone': LucideIcons.bone,
    'check': LucideIcons.check,
    'circle-dashed': LucideIcons.circleDashed,
    'circle-dot': LucideIcons.circleDot,
    'cloud': LucideIcons.cloud,
    'cloud-sun': LucideIcons.cloudSun,
    'crown': LucideIcons.crown,
    'droplets': LucideIcons.droplets,
    'dumbbell': LucideIcons.dumbbell,
    'flame': LucideIcons.flame,
    'lotus': LucideIcons.flower2,
    'footprints': LucideIcons.footprints,
    'frown': LucideIcons.frown,
    'gem': LucideIcons.gem,
    'heart': LucideIcons.heart,
    'help-circle': LucideIcons.circleHelp,
    'hourglass': LucideIcons.hourglass,
    'leaf': LucideIcons.leaf,
    'mars': LucideIcons.mars,
    'meh': LucideIcons.meh,
    'moon': LucideIcons.moon,
    'moon-star': LucideIcons.moonStar,
    'mountain': LucideIcons.mountain,
    'move': LucideIcons.move,
    'scale': LucideIcons.scale,
    'shield-check': LucideIcons.shieldCheck,
    'smile': LucideIcons.smile,
    'sparkles': LucideIcons.sparkles,
    'sprout': LucideIcons.sprout,
    'sun': LucideIcons.sun,
    'sunrise': LucideIcons.sunrise,
    'timer': LucideIcons.timer,
    'trees': LucideIcons.treePine,
    'trending-up': LucideIcons.trendingUp,
    'trophy': LucideIcons.trophy,
    'venus': LucideIcons.venus,
    'waves': LucideIcons.waves,
    'wind': LucideIcons.wind,
    'zap': LucideIcons.zap,
  };

  @override
  Widget build(BuildContext context) => Icon(map[name] ?? LucideIcons.sparkles, size: size, color: color);
}

/// Thin linear bar.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.height = 6, this.track = C.sand, this.color = C.jade, this.gradient});
  final double value;
  final double height;
  final Color track;
  final Color color;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: track,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: kEase,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(decoration: BoxDecoration(color: gradient == null ? color : null, gradient: gradient, borderRadius: BorderRadius.circular(height))),
          ),
        ),
      ),
    );
  }
}

/// Image + scrim hero header used by detail screens.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.image, required this.height, required this.child, this.topBar});
  final String image;
  final double height;
  final Widget child;
  final Widget? topBar;
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        ClipRect(child: KenBurns(child: EImage(image))),
        DecoratedBox(decoration: BoxDecoration(gradient: G.heroTopBottom)),
        if (topBar != null) Positioned(left: 20, right: 20, top: top + 10, child: topBar!),
        Positioned(left: 24, right: 24, bottom: 24, child: child),
      ]),
    );
  }
}
