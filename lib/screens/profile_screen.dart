import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../services/app_links.dart';
import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/ruler_picker.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/tab_shell.dart';
import '../widgets/privacy_sheet.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final premium = app.premium;
    final r = app.reminders;
    final plan = app.activePlan;
    final completed = app.activeCompleted;
    final stats = app.stats;
    final value = bmi(p.heightCm, p.weightKg);
    final goalLabels = {
      for (final o in Content.i.step('goals')?.options ?? const [])
        o.id: o.label,
    };
    final reminderLabel = r.enabled
        ? DateFormat('h:mm a').format(DateTime(2020, 1, 1, r.hour, r.minute))
        : 'Off';
    final planName = switch (premium.plan) {
      'gift' => 'Yearly (gift)',
      'exit' => 'Yearly (special)',
      'lifetime' => 'Lifetime',
      null => '',
      final p => p[0].toUpperCase() + p.substring(1),
    };

    return EnsoScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: topInset(context) + 26,
          bottom: tabBarSpace(context),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: G.jade,
                    shape: BoxShape.circle,
                    boxShadow: S.glow,
                  ),
                  child: Text(
                    (p.name.isNotEmpty ? p.name : 'E')[0].toUpperCase(),
                    style: T.displayXl.copyWith(fontSize: 36, color: C.ivory),
                  ),
                ),
                if (premium.active)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: G.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.cream, width: 3),
                      ),
                      child: const Icon(
                        LucideIcons.crown,
                        size: 16,
                        color: C.ink,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(p.name.isNotEmpty ? p.name : 'Friend', style: T.displayMd),
            const SizedBox(height: 4),
            Text(
              '${premium.active ? 'TaiChi Flow Plus member' : 'Free member'} · ${stats.sessions} sessions',
              style: T.caption.s(14),
            ),
            const SizedBox(height: 16),
            Pressable(
              onTap: () => context.push('/edit-profile'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: C.ivory,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: S.soft,
                ),
                child: Text('Edit profile', style: T.label.s(14)),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Reveal(
                    delay: 0.05,
                    child: !premium.active
                        ? Pressable(
                            onTap: () => context.push('/paywall?from=profile'),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: C.ink,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: S.card,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: G.gold,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      LucideIcons.crown,
                                      size: 28,
                                      color: C.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Try TaiChi Flow Plus free',
                                          style: T.title.c(C.ivory),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'All plans, meditations & voice coaching',
                                          style: T.caption.c(
                                            C.ivory.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 20,
                                    color: C.gold,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Pressable(
                            onTap: premium.plan == 'lifetime'
                                ? null
                                : () => AppLinks.manageSubscription(),
                            child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: C.goldSoft,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: G.gold,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    LucideIcons.crown,
                                    size: 24,
                                    color: C.ink,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TaiChi Flow Plus · $planName',
                                        style: T.title,
                                      ),
                                      Text(
                                        premium.plan == 'lifetime'
                                            ? 'Since ${premium.since != null ? DateFormat.yMd().format(premium.since!) : 'today'} · Yours for life'
                                            : 'Since ${premium.since != null ? DateFormat.yMd().format(premium.since!) : 'today'} · Manage in ${AppLinks.storeName}',
                                        style: T.caption.c(
                                          C.ink.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    delay: 0.1,
                    child: ECard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Body', style: T.title)),
                              Pressable(
                                onTap: () => _logWeight(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.jadeSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    'Log weight',
                                    style: T.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: C.jadeDeep,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  LucideIcons.ruler,
                                  'Height',
                                  formatHeight(p.heightCm, p.units),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Stat(
                                  LucideIcons.scale,
                                  'Weight',
                                  formatWeight(p.weightKg, p.units),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Stat(
                                  LucideIcons.heart,
                                  'Goal',
                                  formatWeight(p.targetWeightKg, p.units),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: C.sand.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'BMI $value',
                                    style: T.label.s(14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.ivory,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    bmiCategory(value),
                                    style: T.tiny.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: C.jadeDeep,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (app.weightLog.length > 1)
                            _WeightSpark(log: app.weightLog),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    delay: 0.14,
                    child: ECard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your goals', style: T.title),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final g
                                  in (p.goals.isEmpty
                                      ? ['wellbeing']
                                      : p.goals))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.jadeSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    goalLabels[g] ?? g,
                                    style: T.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: C.jadeDeep,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Pressable(
                            onTap: () => context.push('/plan/${plan.id}'),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                10,
                                16,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: C.sand.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  RoundedImage(
                                    img(plan.image),
                                    size: 56,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Current plan', style: T.tiny),
                                        Text(
                                          plan.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: T.label.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Ring(
                                    value: completed.length / plan.days.length,
                                    size: 40,
                                    stroke: 4,
                                    child: Text(
                                      '${completed.length}',
                                      style: T.tiny
                                          .copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: C.ink,
                                          )
                                          .tab,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Group(
                    title: 'Practice',
                    children: [
                      _Row(
                        icon: LucideIcons.bell,
                        label: 'Daily reminder',
                        value: reminderLabel,
                        onTap: () => context.push('/reminders'),
                      ),
                      _Row(
                        icon: LucideIcons.slidersHorizontal,
                        label: 'Sound & voice',
                        onTap: () => context.push('/settings'),
                      ),
                      _Row(
                        icon: LucideIcons.chartColumn,
                        label: 'History',
                        value: '${app.history.length} sessions',
                        onTap: () => context.push('/history'),
                      ),
                      _Row(
                        icon: LucideIcons.trophy,
                        label: 'Achievements',
                        value:
                            '${app.unlocked.length}/${Content.i.achievements.length}',
                        onTap: () => context.push('/achievements'),
                      ),
                      Pressable(
                        onTap: () => app.setProfile(
                          (x) => x.units = x.imperial ? 'metric' : 'imperial',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              const _RowIcon(LucideIcons.ruler),
                              const SizedBox(width: 14),
                              Expanded(child: Text('Units', style: T.label)),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: C.sand,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  children: [
                                    for (final u in const [
                                      ('metric', 'kg · cm'),
                                      ('imperial', 'lb · ft'),
                                    ])
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.units == u.$1
                                              ? C.ink
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: Text(
                                          u.$2,
                                          style: T.tiny.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: p.units == u.$1
                                                ? C.ivory
                                                : C.ink,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  _Group(
                    title: 'Support',
                    children: [
                      _Row(
                        icon: LucideIcons.star,
                        label: 'Rate TaiChi Flow',
                        onTap: () => AppLinks.rate(),
                      ),
                      _Row(
                        icon: LucideIcons.share2,
                        label: 'Share with a friend',
                        onTap: () async {
                          await Clipboard.setData(
                            const ClipboardData(
                              text: "I've been practicing Tai Chi with TaiChi Flow — meditation in motion. Join me 🌿",
                            ),
                          );
                          Toast.show(
                            'Invite copied',
                            description: 'Paste it to a friend.',
                          );
                        },
                      ),
                      _Row(
                        icon: LucideIcons.refreshCw,
                        label: 'Restore purchases',
                        onTap: () => _restore(context),
                      ),
                      _Row(
                        icon: LucideIcons.circleHelp,
                        label: 'Help & feedback',
                        onTap: () async {
                          if (!await AppLinks.contact()) {
                            await Clipboard.setData(
                              ClipboardData(text: Content.i.legal.contact),
                            );
                            Toast.show(
                              'Support email copied',
                              description: Content.i.legal.contact,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  _Group(
                    title: 'About',
                    children: [
                      _Row(
                        icon: LucideIcons.shieldCheck,
                        label: 'Privacy choices',
                        onTap: () => _privacyChoices(context),
                      ),
                      _Row(
                        icon: LucideIcons.shield,
                        label: 'Privacy policy',
                        onTap: () => context.push('/legal/privacy'),
                      ),
                      _Row(
                        icon: LucideIcons.fileText,
                        label: 'Terms of use',
                        onTap: () => context.push('/legal/terms'),
                      ),
                      _Row(
                        icon: LucideIcons.trash2,
                        label: 'Reset all data',
                        danger: true,
                        onTap: () => _reset(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FutureBuilder<String>(
                      future: AppLinks.version(),
                      builder: (_, v) => Text(
                        'TaiChi Flow ${v.data ?? ''} · Made with calm',
                        style: T.tiny.w(FontWeight.w400),
                      ),
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

  Future<void> _restore(BuildContext context) async {
    final app = context.read<AppState>();
    Toast.show('Checking your purchases…');
    final ok = await PurchaseService.restore();
    if (ok) {
      if (!app.premium.active) app.setPremium('yearly');
      Toast.show('TaiChi Flow Plus restored', description: 'Welcome back 💚');
    } else {
      Toast.show(
        'No purchase found',
        description: 'Use the same ${AppLinks.storeName} account you bought with.',
      );
    }
  }

  void _privacyChoices(BuildContext context) async {
    final code = await PurchaseService.supportCode();
    if (!context.mounted) return;
    await showPrivacyChoice(context, fromSettings: true, supportCode: code);
  }

  void _logWeight(BuildContext context) {
    final app = context.read<AppState>();
    var draft = app.profile.weightKg;
    showEnsoSheet<void>(
      context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            final imperial = app.profile.imperial;
            final display = imperial ? kgToLb(draft) : draft.round();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                children: [
                  Text("Log today's weight", style: T.title),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$display', style: T.displayXl.tab),
                      const SizedBox(width: 8),
                      Text(
                        imperial ? 'lb' : 'kg',
                        style: T.title.copyWith(
                          color: C.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RulerPicker(
                    min: imperial ? 66 : 30,
                    max: imperial ? 440 : 200,
                    value: display,
                    onChanged: (v) =>
                        setS(() => draft = imperial ? lbToKg(v) : v.toDouble()),
                  ),
                  const SizedBox(height: 24),
                  EnsoButton(
                    label: 'Save',
                    onTap: () {
                      app.logWeight(draft);
                      Navigator.pop(ctx);
                      Toast.show(
                        'Weight logged',
                        description: formatWeight(draft, app.profile.units),
                        tone: 'success',
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _reset(BuildContext context) {
    final app = context.read<AppState>();
    showEnsoSheet<void>(
      context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              Text('Reset everything?', style: T.displayMd),
              const SizedBox(height: 8),
              Text(
                'Your history, streaks, plan progress and settings will be erased from this device.',
                textAlign: TextAlign.center,
                style: T.bodySm.c(C.muted),
              ),
              const SizedBox(height: 24),
              Pressable(
                onTap: () {
                  Navigator.pop(ctx);
                  app.reset();
                  context.go('/welcome');
                },
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.danger,
                    borderRadius: BorderRadius.circular(56),
                  ),
                  child: Text(
                    'Erase & start over',
                    style: T.label.copyWith(fontSize: 17, color: C.ivory),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              EnsoButton(
                label: 'Cancel',
                variant: BtnVariant.ghost,
                size: BtnSize.md,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: C.sand.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: C.jade),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: T.label.copyWith(fontWeight: FontWeight.w700).tab,
        ),
        Text(
          label,
          style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w400),
        ),
      ],
    ),
  );
}

class _WeightSpark extends StatelessWidget {
  const _WeightSpark({required this.log});
  final List<WeightPoint> log;
  @override
  Widget build(BuildContext context) {
    final pts = log.length > 10 ? log.sublist(log.length - 10) : log;
    final delta = ((pts.last.kg - pts.first.kg) * 10).round() / 10;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Weight trend', style: T.tiny)),
              Text(
                '${delta > 0 ? '+' : ''}$delta kg',
                style: T.tiny.copyWith(
                  color: delta <= 0 ? C.jade : C.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparkPainter(pts.map((p) => p.kg).toList()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v);
  final List<double> v;
  @override
  void paint(Canvas canvas, Size size) {
    final mn = v.reduce((a, b) => a < b ? a : b) - 0.5;
    final mx = v.reduce((a, b) => a > b ? a : b) + 0.5;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = i / (v.length - 1).clamp(1, 999) * size.width;
      final y = size.height - (v[i] - mn) / (mx - mn) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = C.jade,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter o) => o.v != v;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: T.tiny.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: C.ivory,
            borderRadius: BorderRadius.circular(26),
            boxShadow: S.soft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: C.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon, {this.danger = false});
  final IconData icon;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: danger ? C.terracottaSoft : C.sand,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 18, color: danger ? C.danger : C.jadeDeep),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.985,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _RowIcon(icon, danger: danger),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: T.label.c(danger ? C.danger : C.ink)),
          ),
          if (value != null) ...[
            Text(value!, style: T.caption.s(14)),
            const SizedBox(width: 6),
          ],
          const Icon(LucideIcons.chevronRight, size: 16, color: C.muted),
        ],
      ),
    ),
  );
}
