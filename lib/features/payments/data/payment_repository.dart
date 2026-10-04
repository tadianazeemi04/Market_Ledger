import 'package:uuid/uuid.dart';
import '../../../core/constants/enums.dart';
import '../../../core/database/database_helper.dart';
import '../domain/payment_model.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper;
  final Uuid _uuid = const Uuid();

  PaymentRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Payment>> getPaymentsForOrder(String orderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'payments',
      where: 'orderId = ?',
      whereArgs: [orderId],
      orderBy: 'paidAt DESC',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<Payment> recordPayment({
    required String orderId,
    required double amount,
    required PaymentMethod method,
    String? referenceNumber,
    String? note,
    DateTime? paidAt,
  }) async {
    final db = await _dbHelper.database;
    final paymentDate = paidAt ?? DateTime.now();
    final paymentId = _uuid.v4();

    final payment = Payment(
      id: paymentId,
      orderId: orderId,
      amount: amount,
      method: method,
      referenceNumber: referenceNumber,
      note: note,
      paidAt: paymentDate,
      createdAt: DateTime.now(),
    );

    await db.transaction((txn) async {
      // 1. Insert payment record
      await txn.insert('payments', payment.toMap());

      // 2. Fetch order
      final orderMaps = await txn.query('orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
      if (orderMaps.isEmpty) {
        throw StateError('Order with ID $orderId not found');
      }

      final orderMap = orderMaps.first;
      final grandTotal = (orderMap['grandTotal'] as num).toDouble();

      // 3. Sum all payments for order
      final sumResult = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0.0) as totalPaid FROM payments WHERE orderId = ?',
        [orderId],
      );
      final double totalPaid = (sumResult.first['totalPaid'] as num).toDouble();

      // 4. Calculate new balance & payment status
      final double newBalance = (grandTotal - totalPaid).clamp(0.0, double.infinity);
      final PaymentStatus newStatus = PaymentStatus.calculate(grandTotal, totalPaid);

      // 5. Update order
      await txn.update(
        'orders',
        {
          'advanceAmount': totalPaid,
          'balanceAmount': newBalance,
          'paymentStatus': newStatus.name,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });

    return payment;
  }
}
