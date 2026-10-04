import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/customer_model.dart';
import '../../orders/domain/order_model.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper;

  CustomerRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Customer>> getCustomers({String? searchQuery}) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT c.*, 
        COUNT(o.id) as totalOrders, 
        COALESCE(SUM(o.grandTotal), 0.0) as totalSpent, 
        MAX(o.orderDate) as lastOrderDate
      FROM customers c
      LEFT JOIN orders o ON (c.id = o.customerId AND COALESCE(o.isDeleted, 0) = 0)
      WHERE COALESCE(c.isDeleted, 0) = 0
    ''';

    List<dynamic> arguments = [];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      sql += '''
        AND (c.shopName LIKE ? 
           OR c.ownerName LIKE ? 
           OR c.marketArea LIKE ? 
           OR c.phone LIKE ?)
      ''';
      arguments = [term, term, term, term];
    }

    sql += ' GROUP BY c.id ORDER BY c.shopName COLLATE NOCASE ASC';

    final result = await db.rawQuery(sql, arguments);
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final db = await _dbHelper.database;
    final sql = '''
      SELECT c.*, 
        COUNT(o.id) as totalOrders, 
        COALESCE(SUM(o.grandTotal), 0.0) as totalSpent, 
        MAX(o.orderDate) as lastOrderDate
      FROM customers c
      LEFT JOIN orders o ON (c.id = o.customerId AND COALESCE(o.isDeleted, 0) = 0)
      WHERE c.id = ? AND COALESCE(c.isDeleted, 0) = 0
      GROUP BY c.id
    ''';
    final result = await db.rawQuery(sql, [id]);
    if (result.isNotEmpty) {
      return Customer.fromMap(result.first);
    }
    return null;
  }

  Future<void> createCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> deleteCustomer(String id) async {
    await _dbHelper.softDeleteCustomer(id);
  }

  Future<void> restoreCustomer(String id) async {
    await _dbHelper.restoreCustomer(id);
  }

  Future<List<Map<String, dynamic>>> getDeletedCustomers() async {
    return await _dbHelper.getDeletedCustomers();
  }

  Future<void> permanentlyDeleteCustomer(String id) async {
    await _dbHelper.permanentlyDeleteCustomer(id);
  }

  Future<List<OrderModel>> getCustomerOrders(String customerId) async {
    final db = await _dbHelper.database;
    final orders = await db.query(
      'orders',
      where: 'customerId = ? AND COALESCE(isDeleted, 0) = 0',
      whereArgs: [customerId],
      orderBy: 'orderDate DESC',
    );
    return orders.map((o) => OrderModel.fromMap(o)).toList();
  }
}
