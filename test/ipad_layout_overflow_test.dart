import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/core/constants/enums.dart';
import 'package:marketledger/features/orders/domain/order_item_model.dart';
import 'package:marketledger/features/orders/domain/order_model.dart';
import 'package:marketledger/features/orders/presentation/order_detail_screen.dart';
import 'package:marketledger/features/orders/presentation/order_providers.dart';
import 'package:marketledger/features/payments/domain/payment_model.dart';
import 'package:marketledger/features/products/domain/product_model.dart';
import 'package:marketledger/features/products/presentation/product_providers.dart';
import 'package:marketledger/features/products/presentation/products_screen.dart';

void main() {
  group('iPad Layout & Two-Pane Overflow Verification', () {
    testWidgets('ProductsScreen renders long multi-line titles without vertical overflow on iPad', (tester) async {
      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final List<Product> testProducts = [
        Product(
          id: 'prod-1',
          name: 'Dalda Banaspati Ghee 1kg x 5 (Multi-Line Packaging Description)',
          sku: 'GHE-005',
          unit: 'Carton',
          unitPrice: 2750.0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: 'prod-2',
          name: "Mitchell's Strawberry Jam 450g x 12 Jars (Commercial Case)",
          sku: 'JAM-012',
          unit: 'Carton',
          unitPrice: 2950.0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Product(
          id: 'prod-3',
          name: 'National Spices Mix Recipe Range Complete Master Carton 50g x 96',
          sku: 'SPC-012',
          unit: 'Carton',
          unitPrice: 3200.0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productListProvider.overrideWith((ref) async => testProducts),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(820, 1180)),
              child: Scaffold(
                body: ProductsScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Dalda Banaspati Ghee'), findsWidgets);
      expect(find.textContaining("Mitchell's Strawberry Jam"), findsWidgets);
      if (caughtDetails != null) {
        // ignore: avoid_print
        print('FLUTTER CAUGHT DETAILS:\n$caughtDetails');
      }
      expect(caughtDetails, isNull);
    });

    testWidgets('OrderDetailScreen renders header chips and long payment ref without overflow on narrow split view', (tester) async {
      tester.view.physicalSize = const Size(380, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testOrder = OrderModel(
        id: 'order-1',
        orderNumber: 'ML-20260924-002',
        customerId: 'cust-1',
        orderDate: DateTime(2026, 9, 24, 11, 45),
        deliveryDate: DateTime(2026, 9, 24),
        status: OrderStatus.delivered,
        paymentStatus: PaymentStatus.paid,
        subtotal: 19500,
        discountAmount: 0,
        deliveryCharge: 0,
        grandTotal: 19500,
        advanceAmount: 19500,
        balanceAmount: 0,
        items: const [
          OrderItem(
            id: 'item-1',
            orderId: 'order-1',
            productId: 'prod-1',
            productNameSnapshot: 'Habib Cooking Oil 5L',
            quantity: 5,
            unit: 'Tin',
            unitPrice: 2650,
            lineTotal: 13250,
          ),
        ],
        payments: [
          Payment(
            id: 'pay-1',
            orderId: 'order-1',
            amount: 19500,
            paidAt: DateTime(2026, 9, 24, 11, 45),
            createdAt: DateTime(2026, 9, 24, 11, 45),
            method: PaymentMethod.bankTransfer,
            referenceNumber: 'FT-889024-MBL-EXTENDED-REF',
            note: 'Full payment transferred directly to Meezan Bank corporate account',
          ),
        ],
        createdAt: DateTime(2026, 9, 24, 11, 45),
        updatedAt: DateTime(2026, 9, 24, 11, 45),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderDetailProvider('order-1').overrideWith((ref) async => testOrder),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(380, 800)),
              child: Scaffold(
                body: OrderDetailScreen(orderId: 'order-1', showBackButton: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ML-20260924-002'), findsWidgets);
      expect(find.textContaining('FT-889024-MBL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
