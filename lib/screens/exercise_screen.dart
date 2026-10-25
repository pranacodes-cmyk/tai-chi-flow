import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/content.dart';
import '../theme/tokens.dart';
import '../widgets/demo_film.dart';
import '../widgets/exercise_body.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';
import '../i18n/i18n.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key, required this.exerciseId});
  final String exerciseId;
  @override
  Widget build(BuildContext context) {
    final e = Content.i.exercise(exerciseId);
    if (e == null) return const NotFoundView();
    return EnsoScaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset(context) + 120),
            child: Column(
              children: [
                SizedBox(
                  height: 440,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DemoFilm(exercise: e),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 96,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [C.cream, Color(0x00F7F3EC)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: topInset(context) + 10,
                        child: const BackBtn(),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: ExerciseBody(exercise: e, hero: false),
                ),
              ],
            ),
          ),
          BottomCta(
            child: EnsoButton(
              label: tr('exercise.practiceForMinutes', {'n': (e.durationSec * 2 / 60).round()}),
              icon: Icons.play_arrow_rounded,
              onTap: () => context.push('/player/ex:${e.id}'),
            ),
          ),
        ],
      ),
    );
  }
}
