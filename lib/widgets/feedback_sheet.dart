import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/feedback_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'sheet.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

Future<void> showFeedbackSheet(BuildContext context) => showEnsoSheet<void>(
  context, builder: (_) => const _FeedbackForm(),
);

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm();
  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _email = TextEditingController();
  final _id = FeedbackService.newId();
  bool _sending = false;
  bool _sent = false;
  String? _error;
  @override
  void dispose() { _message.dispose(); _email.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() { _sending = true; _error = null; });
    try {
      await FeedbackService.send(id: _id, message: _message.text, email: _email.text);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = tr('feedback.sendError2'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: _sent ? Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(LucideIcons.circleCheck, color: C.jade, size: 48),
      const SizedBox(height: 16), Text(tr('feedback.received'), style: T.displayMd),
      const SizedBox(height: 8), Text(tr('feedback.thankYou'), style: T.bodySm, textAlign: TextAlign.center),
      const SizedBox(height: 24), EnsoButton(label: tr('common.done'), onTap: () => Navigator.pop(context)),
    ]) : Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Icon(LucideIcons.messagesSquare, size: 32, color: C.jade),
      const SizedBox(height: 12), Text(tr('feedback.weAreListening'), style: T.displayMd),
      const SizedBox(height: 8), Text(tr('feedback.whatWouldMakeBetter'), style: T.bodySm),
      const SizedBox(height: 24),
      TextFormField(controller: _message, minLines: 3, maxLines: 5, maxLength: 2000,
        decoration: InputDecoration(labelText: tr('feedback.yourMessage'), hintText: tr('feedback.shareIdea')),
        validator: (v) => (v ?? '').trim().isEmpty ? tr('feedback.pleaseWriteMessage') : null),
      const SizedBox(height: 12),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, maxLength: 254,
        decoration: InputDecoration(labelText: tr('feedback.emailOptional'), hintText: tr('feedback.forReplyFromTeam')),
        validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : tr('feedback.enterValidEmail')),
      const SizedBox(height: 8), Text(tr('feedback.privacyNote'), style: T.caption),
      if (_error != null) ...[const SizedBox(height: 12), Text(_error ?? '', style: T.bodySm.c(C.terracotta))],
      const SizedBox(height: 20), EnsoButton(label: tr('feedback.sendMessage'), icon: LucideIcons.send, loading: _sending, onTap: _send),
    ])),
  );
}