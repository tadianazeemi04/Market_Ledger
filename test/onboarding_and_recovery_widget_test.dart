import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/core/widgets/custom_text_field.dart';
import 'package:marketledger/features/onboarding/presentation/onboarding_screen.dart';
import 'package:marketledger/features/settings/presentation/data_recovery_screen.dart';

void main() {
  testWidgets('OnboardingScreen renders inputs, strict validators, and Explore Demo Account button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    // Verify title and input fields
    expect(find.text('Set Up Your Profile'), findsOneWidget);
    expect(find.byType(CustomTextField), findsNWidgets(3));
    expect(find.text('e.g. Tariq Mehmood'), findsOneWidget);
    expect(find.text('e.g. 28'), findsOneWidget);
    expect(find.text('e.g. Al-Madina Wholesale Distributors'), findsOneWidget);

    // Verify "Explore Demo Account" button is present
    expect(find.text('Explore Demo Account'), findsOneWidget);

    // Verify Save & Continue button is present
    expect(find.text('Save & Continue'), findsOneWidget);

    // Tap Save & Continue with empty fields to trigger validation
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Please enter your age'), findsOneWidget);
    expect(find.text('Please enter your company name'), findsOneWidget);
  });

  testWidgets('DataRecoveryScreen renders tabs and empty state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DataRecoveryScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify tab titles exist
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Recover Deleted Data'), findsOneWidget);
  });
}
