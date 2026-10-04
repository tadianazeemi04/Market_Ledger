import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/core/utils/foldable_utils.dart';
import 'package:marketledger/core/widgets/foldable_two_pane.dart';
import 'package:marketledger/core/widgets/workflow_guide_dialog.dart';
import 'package:marketledger/features/customers/presentation/customers_screen.dart';
import 'package:marketledger/features/dashboard/presentation/dashboard_provider.dart';
import 'package:marketledger/features/dashboard/presentation/dashboard_screen.dart';
import 'package:marketledger/features/orders/presentation/orders_screen.dart';
import 'package:marketledger/features/products/presentation/products_screen.dart';
import 'package:marketledger/main.dart';

void main() {
  group('FoldableUtils - iPhone Duo Geometry & Posture Detection', () {
    testWidgets('Detects folded single-screen phone layout', (tester) async {
      late bool isFoldable;
      late bool hasVerticalHinge;
      late bool isTwoPaneEligible;
      late FoldablePaneInfo paneInfo;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              displayFeatures: [],
            ),
            child: Builder(
              builder: (context) {
                isFoldable = FoldableUtils.isFoldable(context);
                hasVerticalHinge = FoldableUtils.getVerticalHinge(context) != null;
                isTwoPaneEligible = FoldableUtils.isTwoPaneEligible(context);
                paneInfo = FoldableUtils.getPaneInfo(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isFoldable, isFalse);
      expect(hasVerticalHinge, isFalse);
      expect(isTwoPaneEligible, isFalse);
      expect(paneInfo.isTwoPane, isFalse);
      expect(paneInfo.hasPhysicalHinge, isFalse);
      expect(paneInfo.leftPaneWidth, 390);
      expect(paneInfo.rightPaneWidth, 0);
    });

    testWidgets('Detects unfolded iPhone Duo dual-screen layout with vertical hinge', (tester) async {
      late bool isFoldable;
      late bool hasVerticalHinge;
      late bool isTwoPaneEligible;
      late FoldablePaneInfo paneInfo;

      const hingeRect = Rect.fromLTWH(375, 0, 10, 800);
      const duoFeatures = [
        DisplayFeature(
          bounds: hingeRect,
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(760, 800),
              displayFeatures: duoFeatures,
            ),
            child: Builder(
              builder: (context) {
                isFoldable = FoldableUtils.isFoldable(context);
                hasVerticalHinge = FoldableUtils.getVerticalHinge(context) != null;
                isTwoPaneEligible = FoldableUtils.isTwoPaneEligible(context);
                paneInfo = FoldableUtils.getPaneInfo(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isFoldable, isTrue);
      expect(hasVerticalHinge, isTrue);
      expect(isTwoPaneEligible, isTrue);
      expect(paneInfo.isTwoPane, isTrue);
      expect(paneInfo.hasPhysicalHinge, isTrue);
      expect(paneInfo.hingeBounds, hingeRect);
      expect(paneInfo.leftPaneWidth, 375);
      expect(paneInfo.rightPaneWidth, 375);
      expect(paneInfo.hingeGap, 10);
    });

    testWidgets('Detects horizontal hinge (tabletop/laptop mode)', (tester) async {
      late bool hasHorizontalHinge;

      const horizontalHingeRect = Rect.fromLTWH(0, 390, 800, 10);
      const tabletopFeatures = [
        DisplayFeature(
          bounds: horizontalHingeRect,
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 800),
              displayFeatures: tabletopFeatures,
            ),
            child: Builder(
              builder: (context) {
                hasHorizontalHinge = FoldableUtils.getHorizontalHinge(context) != null;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(hasHorizontalHinge, isTrue);
    });

    testWidgets('Detects unfolded iPhone Duo 669pt portrait mode as two-pane eligible', (tester) async {
      late bool isTwoPaneEligible;
      late FoldablePaneInfo paneInfo;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(669, 951),
              displayFeatures: [],
            ),
            child: Builder(
              builder: (context) {
                isTwoPaneEligible = FoldableUtils.isTwoPaneEligible(context);
                paneInfo = FoldableUtils.getPaneInfo(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isTwoPaneEligible, isTrue);
      expect(paneInfo.isTwoPane, isTrue);
      expect(paneInfo.hasPhysicalHinge, isFalse);
      expect(paneInfo.leftPaneWidth, greaterThan(260));
      expect(paneInfo.rightPaneWidth, greaterThan(260));
    });
  });

  group('FoldableTwoPane Widget', () {
    testWidgets('Renders singlePane on folded screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              displayFeatures: [],
            ),
            child: Scaffold(
              body: FoldableTwoPane(
                startPane: Text('START_PANE'),
                endPane: Text('END_PANE'),
                singlePane: Text('SINGLE_PANE'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('SINGLE_PANE'), findsOneWidget);
      expect(find.text('START_PANE'), findsNothing);
      expect(find.text('END_PANE'), findsNothing);
    });

    testWidgets('Renders startPane and endPane across vertical hinge on iPhone Duo', (tester) async {
      const duoFeatures = [
        DisplayFeature(
          bounds: Rect.fromLTWH(375, 0, 10, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(760, 800),
              displayFeatures: duoFeatures,
            ),
            child: Scaffold(
              body: FoldableTwoPane(
                startPane: Text('START_PANE'),
                endPane: Text('END_PANE'),
                singlePane: Text('SINGLE_PANE'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('START_PANE'), findsOneWidget);
      expect(find.text('END_PANE'), findsOneWidget);
      expect(find.text('SINGLE_PANE'), findsNothing);
    });
  });

  group('MarketLedgerMainNavigation - iPhone Duo Adaptation', () {
    testWidgets('Renders bottom NavigationBar when iPhone Duo is folded', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MarketLedgerMainNavigation(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('Renders NavigationRail when iPhone Duo is unfolded with vertical hinge', (tester) async {
      tester.view.physicalSize = const Size(760, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const duoFeatures = [
        DisplayFeature(
          bounds: Rect.fromLTWH(375, 0, 10, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith((ref) async => const DashboardMetrics()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(760, 800),
                displayFeatures: duoFeatures,
              ),
              child: const MarketLedgerMainNavigation(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('Screen Master-Detail & Hinge Protection', () {
    testWidgets('DashboardScreen renders two-pane and FAB at endFloat when unfolded', (tester) async {
      tester.view.physicalSize = const Size(760, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const duoFeatures = [
        DisplayFeature(
          bounds: Rect.fromLTWH(375, 0, 10, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith((ref) async => const DashboardMetrics()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(760, 800),
                displayFeatures: duoFeatures,
              ),
              child: DashboardScreen(onNavigateToTab: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FoldableTwoPane), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'New Order'), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.floatingActionButtonLocation, FloatingActionButtonLocation.endFloat);
    });

    testWidgets('OrdersScreen renders FoldableTwoPane and FAB at endFloat', (tester) async {
      tester.view.physicalSize = const Size(760, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const duoFeatures = [
        DisplayFeature(
          bounds: Rect.fromLTWH(375, 0, 10, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ];

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(760, 800),
                displayFeatures: duoFeatures,
              ),
              child: OrdersScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FoldableTwoPane), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.floatingActionButtonLocation, FloatingActionButtonLocation.endFloat);
    });

    testWidgets('CustomersScreen renders FoldableTwoPane and FAB at endFloat', (tester) async {
      tester.view.physicalSize = const Size(760, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const duoFeatures = [
        DisplayFeature(
          bounds: Rect.fromLTWH(375, 0, 10, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ];

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(760, 800),
                displayFeatures: duoFeatures,
              ),
              child: CustomersScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FoldableTwoPane), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.floatingActionButtonLocation, FloatingActionButtonLocation.endFloat);
    });

    testWidgets('ProductsScreen renders FoldableTwoPane and FAB at endFloat', (tester) async {
      tester.view.physicalSize = const Size(760, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const duoFeatures = [
        DisplayFeature(
          bounds: Rect.fromLTWH(375, 0, 10, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ];

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(760, 800),
                displayFeatures: duoFeatures,
              ),
              child: ProductsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FoldableTwoPane), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.floatingActionButtonLocation, FloatingActionButtonLocation.endFloat);
    });

    testWidgets('WorkflowGuideDialog wrapped in DisplayFeatureSubScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    WorkflowGuideDialog.show(context);
                  },
                  child: const Text('OPEN_DIALOG'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN_DIALOG'));
      await tester.pumpAndSettle();

      expect(find.byType(DisplayFeatureSubScreen), findsAtLeastNWidgets(1));
      expect(find.text('How MarketLedger Works'), findsOneWidget);
    });
  });
}
