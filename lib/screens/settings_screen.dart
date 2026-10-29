import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/coach.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/enso_switch.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

List<(String, double)> _rates() => [
  (tr('settings.paceSlow'), 0.8),
  (tr('settings.paceNatural'), 0.95),
  (tr('settings.paceBrisk'), 1.1),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void dispose() {
    Ambient.stop();
    Voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final a = app.audio;
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        t.toUpperCase(),
        style: T.tiny.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
    );

    return EnsoScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: topInset(context) + 10,
          bottom: bottomInset(context) + 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: BackBtn(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('settings.title'), style: T.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    tr('settings.subtitle'),
                    style: T.bodySm.c(C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Reveal(
                    delay: 0.05,
                    child: Container(
                      decoration: BoxDecoration(
                        color: C.ivory,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: S.soft,
                      ),
                      child: Column(
                        children: [
                          _SwitchRow(
                            tr('settings.voiceCoach'),
                            tr('settings.voiceCoachDesc'),
                            a.voice,
                            (v) => app.setAudio((x) => x.voice = v),
                          ),
                          const Divider(height: 1, color: C.line),
                          _SwitchRow(
                            tr('settings.countdownBeeps'),
                            tr('settings.countdownBeepsDesc'),
                            a.beeps,
                            (v) => app.setAudio((x) => x.beeps = v),
                          ),
                          const Divider(height: 1, color: C.line),
                          _SwitchRow(
                            tr('settings.haptics'),
                            tr('settings.hapticsDesc'),
                            a.haptics,
                            (v) => app.setAudio((x) => x.haptics = v),
                          ),
                          const Divider(height: 1, color: C.line),
                          _SwitchRow(
                            tr('settings.backgroundMusic'),
                            tr('settings.backgroundMusicDesc'),
                            a.music,
                            (v) => app.setAudio((x) => x.music = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  label(tr('settings.voicePace')),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: C.sand,
                      borderRadius: BorderRadius.circular(48),
                    ),
                    child: Row(
                      children: [
                        for (final r in _rates())
                          Expanded(
                            child: Pressable(
                              onTap: () =>
                                  app.setAudio((x) => x.voiceRate = r.$2),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: a.voiceRate == r.$2
                                      ? C.ivory
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: a.voiceRate == r.$2
                                      ? S.soft
                                      : null,
                                ),
                                child: Text(
                                  r.$1,
                                  style: T.label.copyWith(
                                    fontSize: 14,
                                    color: a.voiceRate == r.$2
                                        ? C.ink
                                        : C.ink.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  EnsoButton(
                    label: tr('settings.previewVoice'),
                    icon: LucideIcons.volume2,
                    variant: BtnVariant.light,
                    size: BtnSize.md,
                    onTap: () =>
                        Voice.say(CoachLines.preview(), rate: a.voiceRate),
                  ),
                  const SizedBox(height: 24),
                  label(tr('settings.workoutSoundscape')),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.7,
                    children: [
                      for (final s in Content.i.sounds)
                        Pressable(
                          onTap: () {
                            app.setAudio((x) {
                              x.musicTrack = s.id;
                              x.music = true;
                            });
                            Ambient.play(s.id, a.musicVolume * 0.7);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: S.soft,
                              border: Border.all(
                                color: a.musicTrack == s.id
                                    ? C.jade
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  EImage(img(s.image)),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          const Color(0xFF111A15)
                                              .withValues(alpha: 0.75),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (a.musicTrack == s.id)
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: C.jade,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.check,
                                          size: 14,
                                          color: C.ivory,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 12,
                                    bottom: 10,
                                    child: Text(
                                      s.name,
                                      style: T.label.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: C.ivory,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  label(tr('settings.musicVolume')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: S.soft,
                    ),
                    child: Slider(
                      value: a.musicVolume,
                      onChanged: (v) {
                        app.setAudio((x) => x.musicVolume = v);
                        Ambient.setVolume(v * 0.7);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(this.label, this.sub, this.value, this.onChanged);
  final String label, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: T.label),
              Text(sub, style: T.caption),
            ],
          ),
        ),
        const SizedBox(width: 16),
        EnsoSwitch(value: value, onChanged: onChanged, label: label),
      ],
    ),
  );
}
