import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morse_mentor/main.dart';

void main() {
  testWidgets('App smoke test - builds without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MorseMentorApp());

    // Initial pump - app should build without throwing
    await tester.pump();

    // The app shows a loading indicator initially while services init
    // This verifies the app structure is valid even without Hive backend
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
