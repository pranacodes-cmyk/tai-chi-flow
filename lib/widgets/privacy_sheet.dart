import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/tracking_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'sheet.dart';
import 'toast.dart';
import 'ui.dart';

/// Privacy prompts (web `PrivacySheet`): the opt-in choice for consent regions
/// and the explainer shown right before Apple's tracking question on iPhone.
class PrivacyPrompts {
  PrivacyPrompts._();
  static bool _ranThisLaunch = false;

  /// Runs once per launch, shortly after the splash: consent regions answer the
  /// privacy choice first; iPhone users then get the ATT explainer + system
  /// question (only if sharing is allowed and iOS has not asked yet).
  static Future<void> runOnLaunch(BuildContext? Function() context) async {
    if (_ranThisLaunch) return;
    _ranThisLaunch = true;
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    if (TrackingService.needsChoice) {
      final ctx = context();
      if (ctx == null || !ctx.mounted) return;
      await showPrivacyChoice(ctx);
    }
    if (await TrackingService.shouldAskAtt()) {
      final ctx = context();
      if (ctx == null || !ctx.mounted) return;
      await showAttExplainer(ctx);
    } else if (TrackingService.isIOS) {
      await TrackingService.attSkipped();
    }
  }
}

/// Opt-in / opt-out sheet. Both answers are equally easy; closing it without an
/// answer leaves sharing off in consent regions.
Future<void> showPrivacyChoice(
  BuildContext context, {
  bool fromSettings = false,
  String? supportCode,
}) {
  return showEnsoSheet<void>(
    context,
    builder: (ctx) =>
        _PrivacyChoice(fromSettings: fromSettings, supportCode: supportCode),
  );
}

class _PrivacyChoice extends StatelessWidget {
  const _PrivacyChoice({required this.fromSettings, this.supportCode});
  final bool fromSettings;
  final String? supportCode;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final on = TrackingService.allowed;
    void choose(String choice) {
      app.setAdsChoice(choice, TrackingService.deviceCountry);
      Navigator.of(context).pop();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: C.jadeSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.shieldCheck, color: C.jadeDeep, size: 24),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Your privacy, '),
                TextSpan(
                  text: 'your choice',
                  style: T.serifAccent.copyWith(fontSize: 30, color: C.jade),
                ),
              ],
            ),
            style: T.displayMd,
          ),
          const SizedBox(height: 10),
          Text(
            'May TaiChi Flow share a few app events with Meta (Facebook & Instagram) '
            'to measure which of our ads work?',
            style: T.body.c(C.muted),
          ),
          const SizedBox(height: 18),
          const _Point(
            icon: LucideIcons.check,
            tone: C.jade,
            text: 'Shared: app installed and opened, onboarding finished, first '
                'session done, plan viewed and purchases (price only).',
          ),
          const _Point(
            icon: LucideIcons.lock,
            tone: C.terracotta,
            text: 'Never shared: your answers, health or mobility details, name, '
                'or practice history. They stay on this phone.',
          ),
          const _Point(
            icon: LucideIcons.rotateCcw,
            tone: C.muted,
            text: 'Change your mind any time in Profile → Privacy choices.',
          ),
          if (fromSettings) ...[
            const SizedBox(height: 6),
            Text(
              on ? 'Currently: sharing is on.' : 'Currently: sharing is off.',
              style: T.caption.w(FontWeight.w700),
            ),
            if (supportCode != null) ...[
              const SizedBox(height: 10),
              Pressable(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: supportCode!));
                  Toast.show('Support code copied');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: C.sand,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Support code: $supportCode',
                          style: T.tiny.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(LucideIcons.copy, size: 14, color: C.muted),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: EnsoButton(
                  label: "Don't allow",
                  variant: BtnVariant.secondary,
                  onTap: () => choose('denied'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: EnsoButton(
                  label: 'Allow',
                  onTap: () => choose('granted'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/legal/privacy');
              },
              child: Text(
                'Read the privacy policy',
                style: T.caption.copyWith(
                  color: C.jade,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.tone, required this.text});
  final IconData icon;
  final Color tone;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: T.bodySm)),
        ],
      ),
    );
  }
}

/// iPhone: one honest explainer, then Apple's own question. The only button
/// leads straight to the system prompt, where the person decides.
Future<void> showAttExplainer(BuildContext context) async {
  var asked = false;
  await showEnsoSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: C.goldSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.sparkles, color: C.gold, size: 24),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Help us keep ads '),
                TextSpan(
                  text: 'calm',
                  style: T.serifAccent.copyWith(fontSize: 30, color: C.jade),
                ),
              ],
            ),
            style: T.displayMd,
          ),
          const SizedBox(height: 10),
          Text(
            'Next, iPhone asks whether TaiChi Flow may link app events to our ads. '
            'Allowing it shows us which ads bring people here, so we can show '
            'fewer, more relevant ones. Your answers and practice stay on your phone '
            'either way, and every feature works the same whatever you choose.',
            style: T.body.c(C.muted),
          ),
          const SizedBox(height: 22),
          EnsoButton(
            label: 'Continue',
            onTap: () {
              asked = true;
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    ),
  );
  if (asked) {
    await TrackingService.requestAtt();
  } else {
    await TrackingService.attSkipped();
  }
}
