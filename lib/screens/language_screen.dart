import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _countries = {
  'en': 'United States', 'es': 'España', 'pt': 'Brasil',
  'de': 'Deutschland', 'fr': 'France', 'it': 'Italia', 'ja': '日本',
};

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final selected = resolveLanguage(app.language, deviceLanguageTags());
    return EnsoScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: Row(children: [
                Image.asset('assets/images/logo-taichi.png', width: 32, height: 32),
                const SizedBox(width: 10),
                Expanded(child: Text(tr('welcome.brandName'), style: T.label)),
                const Icon(LucideIcons.languages, color: C.jade, size: 24),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
              child: Text(tr('settings.language'), style: T.displayLg.copyWith(letterSpacing: 0)),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                itemCount: supportedLanguages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final code = supportedLanguages[index];
                  final active = selected == code;
                  return Semantics(
                    button: true, selected: active,
                    child: Pressable(
                      onTap: () => app.setLanguage(code),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        constraints: const BoxConstraints(minHeight: 76),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: active ? C.jadeSoft : C.ivory,
                          borderRadius: BorderRadius.circular(R.sm),
                          border: Border.all(color: active ? C.jade : C.line),
                        ),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset('assets/images/flag-$code.png', width: 36, height: 24, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(languageNames[code] ?? code, style: T.label),
                              const SizedBox(height: 3),
                              Text(_countries[code] ?? '', style: T.caption.s(12)),
                            ],
                          )),
                          const SizedBox(width: 8),
                          Icon(active ? LucideIcons.circleCheck : LucideIcons.circle,
                            size: 22, color: active ? C.jadeDeep : C.line),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: EnsoButton(
                label: tr('common.continue'), trailing: LucideIcons.arrowRight,
                onTap: () {
                  if (app.language != selected) app.setLanguage(selected);
                  context.push('/welcome');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}