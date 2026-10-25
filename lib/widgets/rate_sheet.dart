import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../logic/logic.dart';
import '../services/app_links.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'sheet.dart';
import 'toast.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

/// After a completed session: asks for a rating once per day until rated (web `RateSheet`).
Future<void> maybeAskRating(BuildContext context, AppState app) async {
  final today = dateKey(DateTime.now());
  if (!shouldAskRating(app.ratedApp, app.ratePromptDay, today)) return;
  app.markRatePrompted(today);
  await showEnsoSheet<void>(context, builder: (_) => _RateBody(app: app));
}

class _RateBody extends StatefulWidget {
  const _RateBody({required this.app});
  final AppState app;
  @override
  State<_RateBody> createState() => _RateBodyState();
}

class _RateBodyState extends State<_RateBody> {
  int stars = 0;

  void _pick(int s) {
    HapticFeedback.selectionClick();
    setState(() => stars = s);
  }

  Future<void> _submit() async {
    final nav = Navigator.of(context);
    widget.app.setRatedApp();
    nav.pop();
    if (ratingGoesToStore(stars)) {
      Toast.show(tr('rate.thankYou'), description: tr('rate.helpsOthers'), tone: 'success');
      await AppLinks.rate();
    } else {
      Toast.show(tr('rate.thanksForTelling'), description: tr('rate.willMakeItBetter'));
      await AppLinks.contact(subject: tr('rate.feedbackSubject', {'stars': stars}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final low = stars > 0 && !ratingGoesToStore(stars);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(gradient: G.gold, shape: BoxShape.circle, boxShadow: S.glow),
            child: const Icon(LucideIcons.heart, size: 28, color: C.ink),
          ),
          const SizedBox(height: 16),
          Text(tr('rate.enjoyingTaiChiFlow'), style: T.displayMd, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            low ? tr('rate.whatCouldFeelBetter') : tr('rate.quickRatingHelps'),
            style: T.caption.copyWith(fontSize: 15, height: 1.5, color: C.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Semantics(
                  button: true,
                  selected: i == stars,
                  label: tr('rate.starsLabel', {'n': i}),
                  excludeSemantics: true,
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _pick(i),
                  child: AnimatedScale(
                    scale: i <= stars ? 1.15 : 1,
                    duration: Duration(milliseconds: 180 + i * 40),
                    curve: Curves.easeOutBack,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 44,
                        color: i <= stars ? C.gold : C.ink.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          EnsoButton(
            label: stars == 0 ? tr('rate.tapAStarToRate') : (low ? tr('rate.sendFeedback') : tr('rate.rateOnStore', {'store': AppLinks.storeName})),
            variant: stars == 0 ? BtnVariant.secondary : BtnVariant.primary,
            onTap: stars == 0 ? null : _submit,
          ),
          const SizedBox(height: 6),
          EnsoButton(label: tr('rate.notNow'), variant: BtnVariant.ghost, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

/// Invisible widget that opens the rating sheet shortly after the celebration settles.
class RatePromptTrigger extends StatefulWidget {
  const RatePromptTrigger({super.key, required this.app});
  final AppState app;
  @override
  State<RatePromptTrigger> createState() => _RatePromptTriggerState();
}

class _RatePromptTriggerState extends State<RatePromptTrigger> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) maybeAskRating(context, widget.app);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
