import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/main.dart';

void main() {
  testWidgets('MarketLedgerApp responsive navigation: wide screen renders NavigationRail', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MarketLedgerMainNavigation(),
        ),
      ),
    );

    // Verify NavigationRail exists on wide screens (iPad / Mac / Web)
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('MarketLedgerApp responsive navigation: mobile screen renders NavigationBar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MarketLedgerMainNavigation(),
        ),
      ),
    );

    // Verify NavigationBar exists on compact/mobile screens
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
