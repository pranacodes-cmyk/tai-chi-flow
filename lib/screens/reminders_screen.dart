import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/enso_switch.dart';
import '../widgets/scaffold.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import 'onboarding_screen.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  Future<void> _reschedule(AppState app) => NotificationService.schedule(app.reminders, name: app.profile.name, minutes: app.profile.dailyMinutes);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final r = app.reminders;
    final t = formatTime(r.hour, r.minute);
    void shift(int delta) {
      final total = (r.hour * 60 + r.minute + delta + 1440) % 1440;
      app.setReminders((x) {
        x.hour = total ~/ 60;
        x.minute = total % 60;
      });
      _reschedule(app);
    }

    return EnsoScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(top: topInset(context) + 10, bottom: bottomInset(context) + 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: BackBtn()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Daily reminder', style: T.displayLg),
              const SizedBox(height: 4),
              Text('A gentle nudge at the moment that suits you.', style: T.bodySm.c(C.muted)),
            ]),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(26), boxShadow: S.soft),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: C.jadeSoft, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(LucideIcons.bellRing, size: 20, color: C.jadeDeep),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Remind me to practice', style: T.label),
                      Text(r.enabled ? 'On' : 'Off', style: T.caption),
                    ]),
                  ),
                  EnsoSwitch(
                    value: r.enabled,
                    label: 'Reminders',
                    onChanged: (v) async {
                      app.setReminders((x) => x.enabled = v);
                      if (v) await NotificationService.requestPermission();
                      await _reschedule(app);
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: r.enabled ? 1 : 0.4,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !r.enabled,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ECard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleBtn(icon: LucideIcons.minus, tone: Tone.sand, size: 48, label: 'Earlier', onTap: () => shift(-15)),
                          Expanded(
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                              Text(t.time, style: T.displayXl.copyWith(fontSize: 56).tab),
                              const SizedBox(width: 6),
                              Text(t.ampm, style: T.title.copyWith(color: C.muted, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          CircleBtn(icon: LucideIcons.plus, tone: Tone.sand, size: 48, label: 'Later', onTap: () => shift(15)),
                        ]),
                        const SizedBox(height: 24),
                        Text('Repeat on', style: T.caption.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        DayPicker(
                          days: r.days,
                          onChanged: (d) {
                            app.setReminders((x) => x.days = d);
                            _reschedule(app);
                          },
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    Padding(padding: const EdgeInsets.only(left: 8, bottom: 8), child: Text('PREVIEW', style: T.tiny.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2))),
                    NotificationPreview(name: app.profile.name, minutes: app.profile.dailyMinutes, time: '${t.time} ${t.ampm}'),
                    const SizedBox(height: 16),
                    EnsoButton(
                      label: 'Send a test notification',
                      icon: LucideIcons.bell,
                      variant: BtnVariant.light,
                      size: BtnSize.md,
                      onTap: () async {
                        await NotificationService.showTest(name: app.profile.name, minutes: app.profile.dailyMinutes);
                        Toast.show('Test sent', description: 'Check your notification shade.');
                      },
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
