import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypoglycemia_support/main.dart';

void main() {
  testWidgets('typing digits into intake time inserts colon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: IntakePage(onLogin: _noop))));
    final field = find.widgetWithText(TextField, 'Intake time (24-hour)');
    await tester.enterText(field, '');
    for (final step in ['1', '12', '123', '1230']) {
      await tester.enterText(field, step);
    }
    expect(tester.widget<TextField>(field).controller!.text, '12:30');
  });
}

void _noop() {}
