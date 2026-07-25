import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabootar/ui/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('onboarding shows the brand and a call to action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: (String _) async {})),
    );

    expect(find.text('Kabootar'), findsOneWidget);
    expect(find.text('Start messaging'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('start is disabled until a name is entered', (
    WidgetTester tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: (String name) async => submitted = name,
        ),
      ),
    );

    // Tapping with an empty field does nothing.
    await tester.tap(find.text('Start messaging'));
    await tester.pump();
    expect(submitted, isNull);

    // Enter a name and it flows through.
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.tap(find.text('Start messaging'));
    await tester.pump();
    expect(submitted, 'Alex');
  });
}
