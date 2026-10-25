import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../services/app_links.dart';
import '../i18n/i18n.dart';

/// Public insert-only inbox. The publishable key cannot read messages.
class FeedbackService {
  static const _url = 'https://tscfsqsspefeyqdubomc.supabase.co/rest/v1/app_feedback';
  static const _key = 'sb_publishable_D03d-W9aRIAkdQc5OUX7IA_wSFlWvQx';

  static String newId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static Future<void> send({required String id, required String message, required String email}) async {
    final response = await http.post(Uri.parse(_url), headers: {
      'apikey': _key,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    }, body: jsonEncode({
      'id': id, 'message': message.trim(), 'email': email.trim().isEmpty ? null : email.trim(),
      'platform': AppLinks.storeName == 'the App Store' ? 'ios' : 'android',
      'app_version': await AppLinks.version(), 'source': 'today',
    })).timeout(const Duration(seconds: 20));
    // A retry of a previously accepted message is successful without duplicating it.
    if (response.statusCode == 409 && response.body.contains('23505')) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(tr('feedback.sendError'));
    }
  }
}