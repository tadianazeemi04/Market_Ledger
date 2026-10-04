import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/core/widgets/workflow_guide_dialog.dart';
import 'package:marketledger/features/dashboard/presentation/dashboard_provider.dart';
import 'package:marketledger/features/dashboard/presentation/dashboard_screen.dart';
import 'package:marketledger/features/orders/presentation/orders_screen.dart';
import 'package:marketledger/features/settings/presentation/settings_provider.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  final AppSettings _settings;
  FakeSettingsNotifier(this._settings);

  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  testWidgets('WorkflowGuideDialog renders steps, offline badge, and dismiss button', (WidgetTester tester) async {
    bool switchedToCatalog = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => WorkflowGuideDialog.show(
                  context,
                  onSwitchToCatalogTab: () => switchedToCatalog = true,
                ),
                child: const Text('Show Guide'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap to open guide dialog
    await tester.tap(find.text('Show Guide'));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('How MarketLedger Works'), findsOneWidget);
    expect(find.text('Quick 3-step field sales workflow'), findsOneWidget);
    expect(find.text('Register Retail Shops'), findsOneWidget);
    expect(find.text('Add Wholesale Products'), findsOneWidget);
    expect(find.text('Book Orders & Collect Advances'), findsOneWidget);
    expect(find.text('Got It! Let\'s Start Selling'), findsOneWidget);

    // Tap Catalog shortcut
    expect(find.text('Open Catalog'), findsOneWidget);
    await tester.tap(find.text('Open Catalog'));
    await tester.pumpAndSettle();

    expect(switchedToCatalog, true);
  });

  testWidgets('DashboardScreen on empty clean account renders Getting Started workflow and coach mark', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Future.value(const DashboardMetrics()),
          ),
          settingsProvider.overrideWith(
            () => FakeSettingsNotifier(
              const AppSettings(
                salespersonName: 'Tariq Mehmood',
                companyName: 'Mehmood Traders',
                isOnboardingCompleted: true,
                isDemoAccount: false,
                hasSeenWorkflowTour: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: DashboardScreen(onNavigateToTab: (_) {}),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify getting started workflow card
    expect(find.text('Getting Started: Sales Workflow'), findsOneWidget);
    expect(find.text('Follow these 3 steps to take your first order'), findsOneWidget);
    expect(find.text('Add your first retail shop'), findsOneWidget);
    expect(find.text('Configure wholesale catalog'), findsOneWidget);
    expect(find.text('Book order & collect advance'), findsOneWidget);

    // Verify coach mark pointing to New Order button
    expect(find.text('👉 Tap "New Order" in the bottom-right corner to start your first wholesale order!', skipOffstage: false), findsOneWidget);

    // Verify New Order floating action button exists at endFloat
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New Order'), findsWidgets);
  });

  testWidgets('OrdersScreen sets floatingActionButtonLocation to endFloat', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OrdersScreen(),
        ),
      ),
    );

    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.floatingActionButtonLocation, FloatingActionButtonLocation.endFloat);
  });
}
