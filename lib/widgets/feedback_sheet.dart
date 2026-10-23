import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/feedback_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'sheet.dart';
import 'ui.dart';

Future<void> showFeedbackSheet(BuildContext context) => showEnsoSheet<void>(
  context, builder: (_) => const _FeedbackForm(),
);

class FeedbackInvite extends StatelessWidget {
  const FeedbackInvite({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: EnsoButton(label: 'Tell us what you need', icon: LucideIcons.messagesSquare,
      trailing: LucideIcons.arrowRight, variant: BtnVariant.secondary,
      onTap: () => showFeedbackSheet(context)),
  );
}

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
      if (mounted) setState(() => _error = 'Could not send. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: _sent ? Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(LucideIcons.circleCheck, color: C.jade, size: 48),
      const SizedBox(height: 16), Text('Message received', style: T.displayMd),
      const SizedBox(height: 8), Text('Thank you for helping shape TaiChi Flow.', style: T.bodySm, textAlign: TextAlign.center),
      const SizedBox(height: 24), EnsoButton(label: 'Done', onTap: () => Navigator.pop(context)),
    ]) : Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Icon(LucideIcons.messagesSquare, size: 32, color: C.jade),
      const SizedBox(height: 12), Text('We’re listening', style: T.displayMd),
      const SizedBox(height: 8), Text('What would make your practice better?', style: T.bodySm),
      const SizedBox(height: 24),
      TextFormField(controller: _message, minLines: 3, maxLines: 5, maxLength: 2000,
        decoration: const InputDecoration(labelText: 'Your message', hintText: 'Share an idea, request or problem'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Please write a message.' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, maxLength: 254,
        decoration: const InputDecoration(labelText: 'Email (optional)', hintText: 'For a reply from our team'),
        validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email.'),
      const SizedBox(height: 8), Text('Only your message, optional email and app version are sent. Please don’t include health or payment details.', style: T.caption),
      if (_error != null) ...[const SizedBox(height: 12), Text(_error ?? '', style: T.bodySm.c(C.terracotta))],
      const SizedBox(height: 20), EnsoButton(label: 'Send message', icon: LucideIcons.send, loading: _sending, onTap: _send),
    ])),
  );
}