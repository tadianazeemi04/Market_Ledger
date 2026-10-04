import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/core/utils/string_utils.dart';
import 'package:marketledger/features/settings/data/settings_repository.dart';
import 'package:marketledger/features/settings/presentation/settings_provider.dart';
import 'package:marketledger/features/settings/presentation/settings_screen.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  final AppSettings _settings;
  FakeSettingsNotifier(this._settings);

  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  group('StringUtils tests', () {
    test('toTitleCase capitalizes the first letter of each word', () {
      expect(StringUtils.toTitleCase('tariq mehmood'), 'Tariq Mehmood');
      expect(StringUtils.toTitleCase('JOHN DOE'), 'John Doe');
      expect(StringUtils.toTitleCase('alpha wholesale distributors'), 'Alpha Wholesale Distributors');
      expect(StringUtils.toTitleCase('   al-madina   traders  '), 'Al-Madina Traders');
      expect(StringUtils.toTitleCase(''), '');
    });

    test('formatGreetingName formats demo mode as App Reviewer and user name as Title Cased', () {
      // Demo Mode
      const demoSettings = AppSettings(
        salespersonName: 'Any Reviewer Name',
        isDemoAccount: true,
      );
      expect(StringUtils.formatGreetingName(demoSettings), 'App Reviewer');

      // Real User Mode - lowercase
      const userSettingsLower = AppSettings(
        salespersonName: 'tariq mehmood',
        isDemoAccount: false,
      );
      expect(StringUtils.formatGreetingName(userSettingsLower), 'Tariq Mehmood');

      // Real User Mode - uppercase
      const userSettingsUpper = AppSettings(
        salespersonName: 'USMAN ALI KHAN',
        isDemoAccount: false,
      );
      expect(StringUtils.formatGreetingName(userSettingsUpper), 'Usman Ali Khan');

      // Empty name fallback
      const emptySettings = AppSettings(
        salespersonName: '   ',
        isDemoAccount: false,
      );
      expect(StringUtils.formatGreetingName(emptySettings), 'Salesperson');
    });
  });

  group('Multi-Account UI in SettingsScreen', () {
    testWidgets('Active user account renders ACTIVE badge and title cased salesperson name', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(
                const AppSettings(
                  salespersonName: 'tariq mehmood',
                  companyName: 'Alpha Distributors',
                  isDemoAccount: false,
                  isOnboardingCompleted: true,
                ),
              ),
            ),
            savedAccountsProvider.overrideWith((ref) async => [
              SavedAccount(
                id: 'acc_1',
                salespersonName: 'tariq mehmood',
                companyName: 'Alpha Distributors',
                createdAt: DateTime.now(),
                lastActiveAt: DateTime.now(),
              ),
              SavedAccount(
                id: 'acc_2',
                salespersonName: 'usman ali',
                companyName: 'Beta Wholesale Agency',
                createdAt: DateTime.now(),
                lastActiveAt: DateTime.now(),
              ),
            ]),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Active account header
      expect(find.text('Accounts & Profiles'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Tariq Mehmood'), findsOneWidget);
      expect(find.text('Alpha Distributors'), findsWidgets);

      // Other account list
      expect(find.text('Other Saved Accounts (1)'), findsOneWidget);
      expect(find.text('Usman Ali'), findsOneWidget);
      expect(find.text('Beta Wholesale Agency'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);
      expect(find.text('Add Account'), findsOneWidget);
    });

    testWidgets('Demo mode renders App Reviewer and list of saved user accounts', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(
                const AppSettings(
                  salespersonName: 'Apple App Store Reviewer',
                  companyName: 'Wholesale Demo Seed',
                  isDemoAccount: true,
                  isOnboardingCompleted: true,
                ),
              ),
            ),
            savedAccountsProvider.overrideWith((ref) async => [
              SavedAccount(
                id: 'acc_1',
                salespersonName: 'tariq mehmood',
                companyName: 'Alpha Distributors',
                createdAt: DateTime.now(),
                lastActiveAt: DateTime.now(),
              ),
            ]),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Demo Review Account Active'), findsOneWidget);
      expect(find.text('Saved Accounts (1)'), findsOneWidget);
      expect(find.text('Tariq Mehmood'), findsOneWidget);
      expect(find.text('Alpha Distributors'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);
    });

    testWidgets('Tapping Add Account opens Create New Account dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(
                const AppSettings(
                  salespersonName: 'Tariq Mehmood',
                  companyName: 'Alpha Distributors',
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

      await tester.tap(find.text('Add Account'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Create New Account'), findsOneWidget);
      expect(find.text('e.g. Beta Distributors'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('Duplicate company name triggers validation error in Create Account dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(
                const AppSettings(
                  salespersonName: 'Tariq Mehmood',
                  companyName: 'Alpha Distributors',
                  isDemoAccount: false,
                  isOnboardingCompleted: true,
                ),
              ),
            ),
            settingsRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(existingCompanies: ['Alpha Distributors']),
            ),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Account'));
      await tester.pumpAndSettle();

      // Enter details matching existing company inside dialog
      final dialog = find.byType(AlertDialog);
      final textFields = find.descendant(of: dialog, matching: find.byType(TextField));
      await tester.enterText(textFields.at(0), 'Alpha Distributors');
      await tester.enterText(textFields.at(1), 'New Salesperson');

      // Tap Create Account button inside dialog
      await tester.tap(find.descendant(of: dialog, matching: find.text('Create Account')));
      await tester.pumpAndSettle();

      // Verify rejection snackbar appears
      expect(find.textContaining('A company named "Alpha Distributors" already exists'), findsOneWidget);
    });

    testWidgets('Editing company name to an existing company name triggers duplicate error SnackBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => FakeSettingsNotifier(
                const AppSettings(
                  salespersonName: 'Tariq Mehmood',
                  companyName: 'Alpha Distributors',
                  isDemoAccount: false,
                  isOnboardingCompleted: true,
                ),
              ),
            ),
            settingsRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(existingCompanies: ['Alpha Distributors', 'Beta Wholesale']),
            ),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll down so the Distributor & Salesperson Profile card is built
      await tester.scrollUntilVisible(find.text('Save Profile Changes'), 300);
      await tester.pumpAndSettle();

      final companyField = find.byType(TextField).first;
      expect(companyField, findsOneWidget);

      // Change company name to existing company 'Beta Wholesale'
      await tester.enterText(companyField, 'Beta Wholesale');
      await tester.pumpAndSettle();

      // Tap Save Profile Changes
      await tester.ensureVisible(find.text('Save Profile Changes'));
      await tester.tap(find.text('Save Profile Changes'));
      await tester.pumpAndSettle();

      // Verify duplicate error snackbar is shown
      expect(find.textContaining('A company named "Beta Wholesale" already exists'), findsOneWidget);
    });
  });
}

class FakeSettingsRepository extends SettingsRepository {
  final List<String> existingCompanies;
  FakeSettingsRepository({required this.existingCompanies});

  @override
  Future<bool> isCompanyNameTaken(
    String companyName, {
    String? excludeAccountId,
    String? excludeCompanyName,
    bool excludeActiveAccount = false,
  }) async {
    final trimmed = companyName.trim().toLowerCase();
    for (final c in existingCompanies) {
      if (excludeCompanyName != null && c.trim().toLowerCase() == excludeCompanyName.trim().toLowerCase()) {
        continue;
      }
      if (c.trim().toLowerCase() == trimmed) {
        return true;
      }
    }
    return false;
  }
}

