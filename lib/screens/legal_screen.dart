import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/content.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

/// Privacy policy / terms of use (web `legal.$doc`). Same text as the public
/// store-listing pages, generated from scripts/content/legal.ts.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc;

  @override
  Widget build(BuildContext context) {
    final legal = Content.i.legal;
    final d = doc == 'terms' ? legal.terms : legal.privacy;
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
                  Text(d.title, style: T.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    'Last updated ${legal.updated}',
                    style: T.bodySm.c(C.muted),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: C.line),
                    ),
                    child: Text(d.intro, style: T.body),
                  ),
                  for (final s in d.sections) ...[
                    const SizedBox(height: 24),
                    Text(s.heading, style: T.title),
                    const SizedBox(height: 8),
                    for (final p in s.paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(p, style: T.body.c(C.ink.withValues(alpha: 0.82))),
                      ),
                  ],
                  const SizedBox(height: 18),
                  EnsoButton(
                    label: 'Copy contact email',
                    variant: BtnVariant.secondary,
                    icon: LucideIcons.mail,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: legal.contact));
                      Toast.show('Email copied', description: legal.contact);
                    },
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
