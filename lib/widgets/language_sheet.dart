import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../i18n/i18n.dart';
import 'sheet.dart';
import 'ui.dart';

  /// Language picker: the device language (default) or any shipped language, each in its own name.
void showLanguageSheet(BuildContext context) {
    final app = context.read<AppState>();
    final device = resolveLanguage(null, deviceLanguageTags());
    showEnsoSheet<void>(
      context,
      builder: (ctx) {
        Widget option(String? code, String title, [String? subtitle]) {
          final selected = app.language == code;
          return Semantics(
            button: true,
            selected: selected,
            child: Pressable(
              onTap: () {
                Navigator.pop(ctx);
                if (!selected) app.setLanguage(code);
              },
              scale: 0.985,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? C.jadeSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: T.label),
                          if (subtitle != null)
                            Text(subtitle, style: T.caption.s(13)),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(LucideIcons.check, size: 20, color: C.jadeDeep),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('settings.language'),
                style: T.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      option(
                        null,
                        tr('settings.languageSystem'),
                        tr('settings.languageSystemDetail', {
                          'language': languageNames[device],
                        }),
                      ),
                      for (final code in supportedLanguages)
                        option(code, languageNames[code]!),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

