import 'package:flutter_test/flutter_test.dart';
import 'package:marketledger/core/constants/enums.dart';
import 'package:marketledger/features/customers/domain/customer_model.dart';
import 'package:marketledger/features/orders/domain/order_item_model.dart';
import 'package:marketledger/features/orders/domain/order_model.dart';
import 'package:marketledger/features/payments/domain/payment_model.dart';
import 'package:marketledger/features/products/domain/product_model.dart';
import 'package:marketledger/features/receipt/services/receipt_service.dart';
import 'package:marketledger/features/settings/domain/settings_model.dart';

void main() {
  group('Order Calculations & Financial Logic', () {
    test('Calculates line totals and grand totals correctly', () {
      final item1 = OrderItem(
        id: 'i1',
        orderId: 'o1',
        productId: 'p1',
        productNameSnapshot: 'Basmati Rice 25kg',
        quantity: 2.0,
        unit: 'Bag',
        unitPrice: 7400.0,
        discountAmount: 200.0,
        lineTotal: OrderItem.computeLineTotal(2.0, 7400.0, 200.0),
      );

      final item2 = OrderItem(
        id: 'i2',
        orderId: 'o1',
        productId: 'p2',
        productNameSnapshot: 'Cooking Oil 5L',
        quantity: 3.0,
        unit: 'Tin',
        unitPrice: 2650.0,
        discountAmount: 0.0,
        lineTotal: OrderItem.computeLineTotal(3.0, 2650.0, 0.0),
      );

      expect(item1.lineTotal, 14600.0); // 14800 - 200
      expect(item2.lineTotal, 7950.0); // 3 * 2650

      final financials = OrderModel.calculateFinancials(
        items: [item1, item2],
        overallDiscount: 550.0,
        deliveryCharge: 300.0,
        advancePaid: 10000.0,
      );

      expect(financials.subtotal, 22550.0); // 14600 + 7950
      expect(financials.grandTotal, 22300.0); // 22550 - 550 + 300
      expect(financials.advanceAmount, 10000.0);
      expect(financials.balanceAmount, 12300.0); // 22300 - 10000
      expect(financials.paymentStatus, PaymentStatus.partial);
    });

    test('PaymentStatus calculation boundaries', () {
      // Zero paid -> Unpaid
      expect(PaymentStatus.calculate(1000.0, 0.0), PaymentStatus.unpaid);

      // Partial paid -> Partial
      expect(PaymentStatus.calculate(1000.0, 500.0), PaymentStatus.partial);
      expect(PaymentStatus.calculate(1000.0, 999.0), PaymentStatus.partial);

      // Full paid -> Paid
      expect(PaymentStatus.calculate(1000.0, 1000.0), PaymentStatus.paid);

      // Overpaid -> Paid
      expect(PaymentStatus.calculate(1000.0, 1200.0), PaymentStatus.paid);
    });

    test('Financial calculation clamps negative values safely to 0', () {
      final financials = OrderModel.calculateFinancials(
        items: [],
        overallDiscount: 500.0,
        deliveryCharge: 0.0,
        advancePaid: 100.0,
      );

      expect(financials.subtotal, 0.0);
      expect(financials.grandTotal, 0.0);
      expect(financials.balanceAmount, 0.0);
      expect(financials.paymentStatus, PaymentStatus.paid);
    });
  });

  group('Domain Model Serialization & Deserialization', () {
    test('Customer model map conversion', () {
      final now = DateTime(2026, 9, 22, 14, 0);
      final customer = Customer(
        id: 'c-100',
        shopName: 'Madina Traders',
        ownerName: 'Muhammad Akram',
        phone: '0300-1234567',
        marketArea: 'Main Bazaar',
        address: 'Shop 10, Lahore',
        latitude: 31.5204,
        longitude: 74.3587,
        notes: 'Morning delivery only',
        createdAt: now,
        updatedAt: now,
      );

      final map = customer.toMap();
      final fromMap = Customer.fromMap(map);

      expect(fromMap.id, 'c-100');
      expect(fromMap.shopName, 'Madina Traders');
      expect(fromMap.ownerName, 'Muhammad Akram');
      expect(fromMap.phone, '0300-1234567');
      expect(fromMap.latitude, 31.5204);
      expect(fromMap.longitude, 74.3587);
      expect(fromMap.notes, 'Morning delivery only');
      expect(fromMap.hasCoordinates, true);
    });

    test('Product model map conversion', () {
      final now = DateTime(2026, 9, 22, 14, 0);
      final product = Product(
        id: 'p-100',
        name: 'Sugar 50kg',
        sku: 'SGR-050',
        unit: 'Bag',
        unitPrice: 6900.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toMap();
      final fromMap = Product.fromMap(map);

      expect(fromMap.id, 'p-100');
      expect(fromMap.name, 'Sugar 50kg');
      expect(fromMap.unitPrice, 6900.0);
      expect(fromMap.isActive, true);
    });

    test('Payment model map conversion', () {
      final now = DateTime(2026, 9, 22, 14, 0);
      final payment = Payment(
        id: 'pay-1',
        orderId: 'o-1',
        amount: 5000.0,
        method: PaymentMethod.mobileWallet,
        referenceNumber: 'JC-88192',
        note: 'Advance via JazzCash',
        paidAt: now,
        createdAt: now,
      );

      final map = payment.toMap();
      final fromMap = Payment.fromMap(map);

      expect(fromMap.amount, 5000.0);
      expect(fromMap.method, PaymentMethod.mobileWallet);
      expect(fromMap.referenceNumber, 'JC-88192');
    });

    test('AppSettings model map conversion and defaults', () {
      const settings = AppSettings(
        companyName: 'Bismillah Wholesale',
        salespersonName: 'Hamza Khan',
        salespersonPhone: '0321-9988776',
        currency: 'PKR (Rs.)',
        userAge: 29,
        isOnboardingCompleted: true,
        isDemoAccount: false,
      );

      final map = settings.toMap();
      final fromMap = AppSettings.fromMap(map);

      expect(fromMap.companyName, 'Bismillah Wholesale');
      expect(fromMap.salespersonName, 'Hamza Khan');
      expect(fromMap.currency, 'PKR (Rs.)');
      expect(fromMap.userAge, 29);
      expect(fromMap.isOnboardingCompleted, true);
      expect(fromMap.isDemoAccount, false);
      expect(fromMap.hasSeenWorkflowTour, false);
    });

    test('Customer soft-delete properties map conversion', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'cust-del-1',
        shopName: 'Test Shop',
        ownerName: 'Ali Khan',
        phone: '03001234567',
        marketArea: 'Main Bazaar',
        address: 'Shop 1',
        isDeleted: true,
        deletedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final map = customer.toMap();
      expect(map['isDeleted'], 1);
      expect(map['deletedAt'], now.toIso8601String());

      final fromMap = Customer.fromMap(map);
      expect(fromMap.isDeleted, true);
      expect(fromMap.deletedAt != null, true);
    });

    test('Product soft-delete properties map conversion', () {
      final now = DateTime.now();
      final product = Product(
        id: 'prod-del-1',
        name: 'Salt 1kg',
        sku: 'SLT-001',
        unit: 'Pkt',
        unitPrice: 50.0,
        isDeleted: true,
        deletedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toMap();
      expect(map['isDeleted'], 1);
      expect(map['deletedAt'], now.toIso8601String());

      final fromMap = Product.fromMap(map);
      expect(fromMap.isDeleted, true);
    });

    test('Order soft-delete properties map conversion', () {
      final now = DateTime.now();
      final order = OrderModel(
        id: 'ord-del-1',
        orderNumber: 'ML-20260922-999',
        customerId: 'cust-1',
        orderDate: now,
        status: OrderStatus.draft,
        subtotal: 1000.0,
        grandTotal: 1000.0,
        advanceAmount: 0.0,
        balanceAmount: 1000.0,
        paymentStatus: PaymentStatus.unpaid,
        isDeleted: true,
        deletedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final map = order.toMap();
      expect(map['isDeleted'], 1);
      expect(map['deletedAt'], now.toIso8601String());

      final fromMap = OrderModel.fromMap(map);
      expect(fromMap.isDeleted, true);
    });
  });

  group('Validation Logic for Onboarding and Form Fields', () {
    test('Name validation strictly allows only text and rejects digits', () {
      final nameRegex = RegExp(r'^[a-zA-Z\s\.\-]+$');

      // Valid names
      expect(nameRegex.hasMatch('Tariq Mehmood'), true);
      expect(nameRegex.hasMatch('Dr. John Doe-Smith'), true);
      expect(nameRegex.hasMatch('Muhammad Imran'), true);

      // Invalid names containing numbers or forbidden symbols
      expect(nameRegex.hasMatch('Tariq123'), false);
      expect(nameRegex.hasMatch('Agent 007'), false);
      expect(nameRegex.hasMatch('12345'), false);
      expect(nameRegex.hasMatch('John@Doe'), false);
    });

    test('Age validation enforces digits only and minimum age 4', () {
      bool isValidAge(String? input) {
        if (input == null || input.trim().isEmpty) return false;
        final val = int.tryParse(input.trim());
        if (val == null) return false;
        return val >= 4 && val <= 120;
      }

      // Valid ages (from age 4 and up)
      expect(isValidAge('4'), true);
      expect(isValidAge('18'), true);
      expect(isValidAge('25'), true);
      expect(isValidAge('65'), true);

      // Invalid ages (< 4, non-numbers, negative)
      expect(isValidAge('0'), false);
      expect(isValidAge('1'), false);
      expect(isValidAge('2'), false);
      expect(isValidAge('3'), false);
      expect(isValidAge('-5'), false);
      expect(isValidAge('abc'), false);
      expect(isValidAge('18.5'), false);
      expect(isValidAge(''), false);
      expect(isValidAge(null), false);
    });

    test('Phone number validator enforces numeric presence', () {
      bool isValidPhone(String? input) {
        if (input == null || input.trim().isEmpty) return true; // Optional field
        final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
        return digits.length >= 7;
      }

      expect(isValidPhone('03001234567'), true);
      expect(isValidPhone('+92 300 1234567'), true);
      expect(isValidPhone('0300-1234567'), true);
      expect(isValidPhone(''), true);
      expect(isValidPhone('123'), false); // Too short
    });
  });

  group('Receipt Summary Generator', () {
    test('Generates clean formatted text summary', () {
      final now = DateTime(2026, 9, 22, 14, 30);
      final customer = Customer(
        id: 'c1',
        shopName: 'Madina Karyana Store',
        ownerName: 'Imran',
        phone: '0300-1122334',
        marketArea: 'Anarkali',
        address: 'Main Gate',
        createdAt: now,
        updatedAt: now,
      );

      final item = OrderItem(
        id: 'i1',
        orderId: 'o1',
        productId: 'p1',
        productNameSnapshot: 'Tea 900g',
        quantity: 5.0,
        unit: 'Box',
        unitPrice: 1480.0,
        discountAmount: 0.0,
        lineTotal: 7400.0,
      );

      final order = OrderModel(
        id: 'o1',
        orderNumber: 'ML-20260922-001',
        customerId: customer.id,
        orderDate: now,
        status: OrderStatus.confirmed,
        subtotal: 7400.0,
        discountAmount: 100.0,
        deliveryCharge: 200.0,
        grandTotal: 7500.0,
        advanceAmount: 2500.0,
        balanceAmount: 5000.0,
        paymentStatus: PaymentStatus.partial,
        notes: 'Pack in bubble wrap',
        createdAt: now,
        updatedAt: now,
        customer: customer,
        items: [item],
      );

      const settings = AppSettings(
        companyName: 'Alpha Wholesale',
        salespersonName: 'Tariq',
        salespersonPhone: '0300-1234567',
        currency: 'PKR (Rs.)',
      );

      final receipt = ReceiptService.generateTextSummary(order, settings);

      expect(receipt.contains('MARKETLEDGER'), true);
      expect(receipt.contains('ML-20260922-001'), true);
      expect(receipt.contains('Madina Karyana Store'), true);
      expect(receipt.contains('Tea 900g'), true);
      expect(receipt.contains('Rs. 7,500'), true);
      expect(receipt.contains('Rs. 2,500'), true);
      expect(receipt.contains('Rs. 5,000'), true);
      expect(receipt.contains('Alpha Wholesale'), true);
      expect(receipt.contains('Thank you for your business!'), true);
    });
  });
}
