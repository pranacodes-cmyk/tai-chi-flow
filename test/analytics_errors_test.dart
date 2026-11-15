import 'package:flutter_test/flutter_test.dart';
import 'package:enso/services/analytics_service.dart';

void main() {
  test('Error report keeps type, 200-char message and first app frame', () {
    final stack = StackTrace.fromString('#0 dart:core\n#1 Foo (package:enso/screens/today.dart:12:3)\n');
    final r = AnalyticsService.errorReport(StateError('x' * 300), stack, source: 'flutter');
    expect(r['error_type'], 'StateError');
    expect((r['message'] as String).length, 200);
    expect(r['location'], contains('package:enso/screens/today.dart:12'));
    expect(r['source'], 'flutter');
    expect(r['fatal'], false);
  });
}
