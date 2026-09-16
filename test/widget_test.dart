import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lokko_market/main.dart';

void main() {
  testWidgets('Lokko Dashboard Load Test', (WidgetTester tester) async {

    // 🟩 FIXED: LokkoApp no longer requires 'initFuture' thanks to our single-splash update!
    await tester.pumpWidget(
      const ProviderScope(
        child: LokkoApp(), // Clean, parameter-free initialization
      ),
    );

    // Give the test engine time to process layout frame animations smoothly
    await tester.pumpAndSettle();

    // Verify your custom LOKKO UI elements render properly without throwing framework layout crashes
    expect(find.byType(TextField), findsOneWidget);
  });
}