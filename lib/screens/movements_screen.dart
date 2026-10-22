import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

/// Searchable library of every movement (web: /movements).
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key, this.initialCategory});
  final String? initialCategory;
  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  final _query = TextEditingController();
  late String _cat = widget.initialCategory ?? 'all';

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Exercise> get _results {
    final q = _query.text.trim().toLowerCase();
    return Content.i.exercises.where((e) {
      if (e.isAffirmation) return false;
      if (_cat != 'all' && e.category != _cat) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.focus.any((f) => f.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = Content.i;
    final results = _results;
    return EnsoScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topInset(context) + 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: BackBtn(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Text('All movements', style: T.displayLg),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              '${results.length} guided movements',
              style: T.bodySm.c(C.muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: C.ivory,
                borderRadius: BorderRadius.circular(20),
                boxShadow: S.soft,
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.search, size: 20, color: C.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      style: T.body.c(C.ink),
                      cursorColor: C.jade,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search movements or body areas',
                        hintStyle: T.body.c(C.muted),
                      ),
                    ),
                  ),
                  if (_query.text.isNotEmpty)
                    Pressable(
                      onTap: _query.clear,
                      child: const Icon(
                        LucideIcons.x,
                        size: 18,
                        color: C.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              children: [
                ChipPill(
                  label: 'All',
                  active: _cat == 'all',
                  onTap: () => setState(() => _cat = 'all'),
                ),
                for (final cat in c.categories) ...[
                  const SizedBox(width: 8),
                  ChipPill(
                    label: cat.name,
                    active: _cat == cat.id,
                    onTap: () => setState(() => _cat = cat.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.searchX,
                          size: 36,
                          color: C.muted,
                        ),
                        const SizedBox(height: 12),
                        Text('No movements found', style: T.title),
                        const SizedBox(height: 4),
                        Text(
                          'Try another word, or clear the filter.',
                          textAlign: TextAlign.center,
                          style: T.bodySm.c(C.muted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      bottomInset(context) + 24,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final e = results[i];
                      final cat = c.category(e.category)?.name ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ThumbRow(
                          image: img(e.image),
                          title: e.name,
                          subtitle: '$cat · ${e.focus.take(2).join(' · ')}',
                          onTap: () => context.push('/exercise/${e.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
