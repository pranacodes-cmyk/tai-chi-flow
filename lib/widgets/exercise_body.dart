import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'sheet.dart';
import 'ui.dart';

Future<void> showExerciseSheet(BuildContext context, Exercise e) =>
    showEnsoSheet<void>(context, builder: (_) => ExerciseBody(exercise: e));

/// Exercise how-to (web ExerciseBody).
class ExerciseBody extends StatelessWidget {
  const ExerciseBody({super.key, required this.exercise, this.hero = true});
  final Exercise exercise;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hero)
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(height: 260, width: double.infinity, child: ColoredBox(color: C.sand, child: EImage(img(e.image)))),
          ),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in e.focus) _Tag(f, C.jadeSoft, C.jadeDeep),
          _Tag(e.isAffirmation ? 'Affirmation' : e.level, C.sand, C.ink),
        ]),
        const SizedBox(height: 12),
        Text(e.name, style: T.displayMd),
        const SizedBox(height: 8),
        if (e.isAffirmation)
          Text(e.description, style: T.serifAccent.copyWith(fontSize: 22, height: 1.3, color: C.jadeDeep))
        else
          Text(e.description, style: T.bodySm.copyWith(color: C.ink.withValues(alpha: 0.8), height: 1.6)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(22), boxShadow: S.soft),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(e.isAffirmation ? 'Practice' : 'How to', color: C.jade),
            const SizedBox(height: 12),
            for (final (i, s) in e.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: C.jade, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.ivory)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s, style: T.bodySm.copyWith(height: 1.55))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _InfoBox('Breath', e.breath)),
          const SizedBox(width: 12),
          Expanded(child: _InfoBox('Benefits', e.benefits.join(' · '))),
        ]),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: fg)),
      );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.label, this.text);
  final String label, text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(22), boxShadow: S.soft),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(label),
          const SizedBox(height: 6),
          Text(text, style: T.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink, height: 1.35)),
        ]),
      );
}
