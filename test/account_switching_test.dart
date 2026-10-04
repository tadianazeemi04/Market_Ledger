import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/features/onboarding/presentation/onboarding_screen.dart';
import 'package:marketledger/features/settings/presentation/settings_provider.dart';
import 'package:marketledger/features/settings/presentation/settings_screen.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  final AppSettings _settings;
  FakeSettingsNotifier(this._settings);

  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  testWidgets('SettingsScreen in User Account mode renders Explore Demo Account button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => FakeSettingsNotifier(
              const AppSettings(
                salespersonName: 'Tariq Mehmood',
                companyName: 'Alpha Wholesale Distributors',
                isDemoAccount: false,
                isOnboardingCompleted: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Explore Demo Account button is present
    expect(find.text('Explore Demo Account'), findsOneWidget);
    // Verify Demo Review Account Active banner is NOT present
    expect(find.text('Demo Review Account Active'), findsNothing);
  });

  testWidgets('SettingsScreen in Demo mode displays active review banner and options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => FakeSettingsNotifier(
              const AppSettings(
                salespersonName: 'Apple App Store Reviewer',
                companyName: 'Global Wholesale Traders',
                isDemoAccount: true,
                isOnboardingCompleted: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify demo active card exists
    expect(find.text('Demo Review Account Active'), findsOneWidget);
    expect(find.text('Apple Review & Testing Mode'), findsOneWidget);
    expect(find.textContaining('You are exploring pre-seeded wholesale data'), findsOneWidget);
  });

  testWidgets('OnboardingScreen renders header and form correctly', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set Up Your Profile'), findsOneWidget);
    expect(find.text('Explore Demo Account'), findsOneWidget);
    expect(find.text('Save & Continue'), findsOneWidget);
  });
}
