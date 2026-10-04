import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/enums.dart';
import '../../../core/database/database_helper.dart';
import '../../customers/domain/customer_model.dart';
import '../domain/order_model.dart';
import '../domain/order_item_model.dart';
import '../../payments/domain/payment_model.dart';

class OrderRepository {
  final DatabaseHelper _dbHelper;
  final Uuid _uuid = const Uuid();

  OrderRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> generateNextOrderNumber([DateTime? date]) async {
    final targetDate = date ?? DateTime.now();
    final datePrefix = DateFormat('yyyyMMdd').format(targetDate);
    final prefix = 'ML-$datePrefix-';

    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM orders WHERE orderNumber LIKE ?',
      ['$prefix%'],
    );

    final count = (result.first['count'] as num).toInt();
    final nextNumber = (count + 1).toString().padLeft(3, '0');
    return '$prefix$nextNumber';
  }

  Future<List<OrderModel>> getOrders({
    String? query,
    String? customerId,
    String? marketArea,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    String sql = '''
      SELECT o.*, 
        c.shopName as c_shopName,
        c.ownerName as c_ownerName,
        c.phone as c_phone,
        c.marketArea as c_marketArea,
        c.address as c_address,
        c.latitude as c_latitude,
        c.longitude as c_longitude,
        c.notes as c_notes,
        c.createdAt as c_createdAt,
        c.updatedAt as c_updatedAt
      FROM orders o
      LEFT JOIN customers c ON o.customerId = c.id
    ''';

    List<String> conditions = ['COALESCE(o.isDeleted, 0) = 0'];
    List<dynamic> args = [];

    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim()}%';
      conditions.add('(o.orderNumber LIKE ? OR c.shopName LIKE ? OR c.ownerName LIKE ? OR c.marketArea LIKE ?)');
      args.addAll([term, term, term, term]);
    }

    if (customerId != null && customerId.isNotEmpty) {
      conditions.add('o.customerId = ?');
      args.add(customerId);
    }

    if (marketArea != null && marketArea.isNotEmpty) {
      conditions.add('c.marketArea LIKE ?');
      args.add('%$marketArea%');
    }

    if (status != null) {
      conditions.add('o.status = ?');
      args.add(status.name);
    }

    if (paymentStatus != null) {
      conditions.add('o.paymentStatus = ?');
      args.add(paymentStatus.name);
    }

    if (startDate != null) {
      conditions.add('o.orderDate >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      // Inclusive of the entire end date
      final endOfTargetDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      conditions.add('o.orderDate <= ?');
      args.add(endOfTargetDate.toIso8601String());
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }

    sql += ' ORDER BY o.orderDate DESC';

    final results = await db.rawQuery(sql, args);

    return results.map((row) {
      Customer? customer;
      if (row['c_shopName'] != null) {
        customer = Customer(
          id: row['customerId'] as String,
          shopName: row['c_shopName'] as String,
          ownerName: row['c_ownerName'] as String,
          phone: (row['c_phone'] as String?) ?? '',
          marketArea: (row['c_marketArea'] as String?) ?? '',
          address: (row['c_address'] as String?) ?? '',
          latitude: row['c_latitude'] != null ? (row['c_latitude'] as num).toDouble() : null,
          longitude: row['c_longitude'] != null ? (row['c_longitude'] as num).toDouble() : null,
          notes: row['c_notes'] as String?,
          createdAt: DateTime.tryParse(row['c_createdAt'] as String? ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(row['c_updatedAt'] as String? ?? '') ?? DateTime.now(),
        );
      }

      return OrderModel.fromMap(row, customer: customer);
    }).toList();
  }

  Future<OrderModel?> getOrderById(String id) async {
    final db = await _dbHelper.database;

    // 1. Fetch order & customer
    final orderResults = await db.rawQuery('''
      SELECT o.*, 
        c.shopName as c_shopName,
        c.ownerName as c_ownerName,
        c.phone as c_phone,
        c.marketArea as c_marketArea,
        c.address as c_address,
        c.latitude as c_latitude,
        c.longitude as c_longitude,
        c.notes as c_notes,
        c.createdAt as c_createdAt,
        c.updatedAt as c_updatedAt
      FROM orders o
      LEFT JOIN customers c ON o.customerId = c.id
      WHERE o.id = ? AND COALESCE(o.isDeleted, 0) = 0
    ''', [id]);

    if (orderResults.isEmpty) return null;
    final row = orderResults.first;

    Customer? customer;
    if (row['c_shopName'] != null) {
      customer = Customer(
        id: row['customerId'] as String,
        shopName: row['c_shopName'] as String,
        ownerName: row['c_ownerName'] as String,
        phone: (row['c_phone'] as String?) ?? '',
        marketArea: (row['c_marketArea'] as String?) ?? '',
        address: (row['c_address'] as String?) ?? '',
        latitude: row['c_latitude'] != null ? (row['c_latitude'] as num).toDouble() : null,
        longitude: row['c_longitude'] != null ? (row['c_longitude'] as num).toDouble() : null,
        notes: row['c_notes'] as String?,
        createdAt: DateTime.tryParse(row['c_createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(row['c_updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
    }

    // 2. Fetch order items
    final itemResults = await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [id],
    );
    final items = itemResults.map((m) => OrderItem.fromMap(m)).toList();

    // 3. Fetch payments
    final paymentResults = await db.query(
      'payments',
      where: 'orderId = ?',
      whereArgs: [id],
      orderBy: 'paidAt DESC',
    );
    final payments = paymentResults.map((m) => Payment.fromMap(m)).toList();

    return OrderModel.fromMap(row, customer: customer, items: items, payments: payments);
  }

  Future<void> createOrder({
    required OrderModel order,
    required List<OrderItem> items,
    PaymentMethod initialPaymentMethod = PaymentMethod.cash,
    String? paymentRef,
    String? paymentNote,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Insert order
      await txn.insert('orders', order.toMap());

      // 2. Insert items
      for (final item in items) {
        await txn.insert('order_items', item.toMap());
      }

      // 3. If advance amount was recorded, insert initial payment record
      if (order.advanceAmount > 0) {
        final payment = Payment(
          id: _uuid.v4(),
          orderId: order.id,
          amount: order.advanceAmount,
          method: initialPaymentMethod,
          referenceNumber: paymentRef,
          note: paymentNote ?? 'Advance payment at order creation',
          paidAt: order.orderDate,
          createdAt: DateTime.now(),
        );
        await txn.insert('payments', payment.toMap());
      }
    });
  }

  Future<void> updateOrder({
    required OrderModel order,
    required List<OrderItem> items,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Calculate existing total paid from payments table
      final sumResult = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0.0) as totalPaid FROM payments WHERE orderId = ?',
        [order.id],
      );
      final double totalPaid = (sumResult.first['totalPaid'] as num).toDouble();

      final double newBalance = (order.grandTotal - totalPaid).clamp(0.0, double.infinity);
      final PaymentStatus newStatus = PaymentStatus.calculate(order.grandTotal, totalPaid);

      final updatedOrder = order.copyWith(
        advanceAmount: totalPaid,
        balanceAmount: newBalance,
        paymentStatus: newStatus,
        updatedAt: DateTime.now(),
      );

      // 2. Update order
      await txn.update(
        'orders',
        updatedOrder.toMap(),
        where: 'id = ?',
        whereArgs: [order.id],
      );

      // 3. Replace order items
      await txn.delete('order_items', where: 'orderId = ?', whereArgs: [order.id]);
      for (final item in items) {
        await txn.insert('order_items', item.toMap());
      }
    });
  }

  Future<void> markDelivered(String orderId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {
        'status': OrderStatus.delivered.name,
        'deliveryDate': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> deleteOrder(String orderId) async {
    await _dbHelper.softDeleteOrder(orderId);
  }

  Future<void> restoreOrder(String orderId) async {
    await _dbHelper.restoreOrder(orderId);
  }

  Future<List<Map<String, dynamic>>> getDeletedOrders() async {
    return await _dbHelper.getDeletedOrders();
  }

  Future<void> permanentlyDeleteOrder(String orderId) async {
    await _dbHelper.permanentlyDeleteOrder(orderId);
  }
}
