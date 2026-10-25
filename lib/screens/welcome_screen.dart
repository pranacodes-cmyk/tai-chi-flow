import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

const _pillars = ['Balance', 'Flexibility', 'Calm'];

/// First screen: looping practice film (poster image until it plays), headline and the quiz CTA.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  VideoPlayerController? _video;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final v = VideoPlayerController.asset(
      'assets/video/welcome.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = v;
    v
        .initialize()
        .then((_) async {
          if (!mounted) return;
          await v.setVolume(0);
          await v.setLooping(true);
          await v.play();
          if (mounted) setState(() => _playing = true);
        })
        .catchError((_) {
          // poster image stays visible if the device cannot play the film
        });
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = topInset(context);
    final bottom = bottomInset(context);
    final focus = Content.i.focusOf('hero-welcome');
    final avatars = Content.i.testimonials.take(4).toList();
    final v = _video;
    return EnsoScaffold(
      background: C.forest,
      lightIcons: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: KenBurns(
              child: EImage(img('hero-welcome'), alignment: focus),
            ),
          ),
          if (v != null && v.value.isInitialized)
            AnimatedOpacity(
              opacity: _playing ? 1 : 0,
              duration: const Duration(milliseconds: 1000),
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: focus,
                  child: SizedBox(
                    width: v.value.size.width,
                    height: v.value.size.height,
                    child: VideoPlayer(v),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 150,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    C.forest.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height * 0.68,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00141E19),
                    Color(0x8C141E19),
                    Color(0xF0111A15),
                  ],
                  stops: [0, 0.38, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, top + 22, 28, bottom + 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Reveal(
                  delay: 0.2,
                  dy: -8,
                  child: Row(
                    children: [
                      Image.asset(
                        img('logo-taichi-light.png'),
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr('welcome.brandName'),
                        style: T.label.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: C.ivory,
                          letterSpacing: -0.34,
                        ),
                      ),
                      const Spacer(),
                      Glass(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: C.gold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('welcome.rating'),
                              style: T.tiny.copyWith(color: C.ivory),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Reveal(
                  delay: 0.35,
                  dy: 12,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final p in _pillars)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: C.ivory.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: C.ivory.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            trTag(p),
                            style: T.tiny.copyWith(
                              color: C.ivory.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Reveal(
                  delay: 0.45,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: tr('welcome.headlineLine1')),
                        TextSpan(
                          text: tr('welcome.headlineLine2'),
                          style: T.serifAccent.copyWith(
                            fontSize: 54.4,
                            color: C.ivory,
                            height: 0.9,
                          ),
                        ),
                      ],
                    ),
                    style: T.displayXl.copyWith(fontSize: 46.4, color: C.ivory),
                  ),
                ),
                const SizedBox(height: 16),
                Reveal(
                  delay: 0.6,
                  dy: 14,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      tr('welcome.subtitle'),
                      style: T.body.copyWith(
                        fontSize: 17,
                        color: C.ivory.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Reveal(
                  delay: 0.75,
                  dy: 0,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 32.0 + (avatars.length - 1) * 22,
                        height: 32,
                        child: Stack(
                          children: [
                            for (final (i, t) in avatars.indexed)
                              Positioned(
                                left: i * 22.0,
                                child: Avatar(
                                  t.avatar ?? 'onb-age-f-50',
                                  size: 32,
                                  ring: C.forest,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Stars(size: 13),
                            const SizedBox(height: 2),
                            Text(
                              tr('welcome.lovedBy'),
                              softWrap: true,
                              style: T.tiny.copyWith(
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                                color: C.ivory.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Reveal(
                  delay: 0.85,
                  dy: 20,
                  child: Column(
                    children: [
                      Shimmer(
                        color: C.jadeSoft,
                        child: EnsoButton(
                          label: tr('welcome.ctaLabel'),
                          variant: BtnVariant.ivory,
                          trailing: LucideIcons.arrowRight,
                          onTap: () => context.go('/onboarding'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('welcome.quizNote'),
                        style: T.caption.copyWith(
                          color: C.ivory.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _LegalLine(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "By continuing, you agree to our Terms and Privacy Policy." — mirrors the web welcome footer.
class _LegalLine extends StatelessWidget {
  const _LegalLine();

  @override
  Widget build(BuildContext context) {
    final base = T.tiny.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: C.ivory.withValues(alpha: 0.5),
    );
    final link = base.copyWith(
      fontWeight: FontWeight.w600,
      color: C.ivory.withValues(alpha: 0.8),
      decoration: TextDecoration.underline,
      decorationColor: C.ivory.withValues(alpha: 0.4),
    );
    Widget tap(String label, String doc) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/legal/$doc'),
          child: Text(label, style: link),
        );
    // links render wherever the language places {terms} and {privacy}
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final part in trParts('welcome.legalLine'))
          switch (part.name) {
            'terms' => tap(tr('welcome.termsLabel'), 'terms'),
            'privacy' => tap(tr('welcome.privacyLabel'), 'privacy'),
            _ => Text(part.text, style: base),
          },
      ],
    );
  }
}
