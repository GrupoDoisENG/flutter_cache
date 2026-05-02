import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_problematico_catalog/main.dart';

void main() {
  testWidgets('MyApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
