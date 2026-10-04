import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/product_model.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper;

  ProductRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Product>> getProducts({String? searchQuery, bool activeOnly = false}) async {
    final db = await _dbHelper.database;
    List<String> conditions = ['COALESCE(isDeleted, 0) = 0'];
    List<dynamic> whereArgs = [];

    if (activeOnly) {
      conditions.add('isActive = 1');
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      conditions.add('(name LIKE ? OR sku LIKE ?)');
      whereArgs.addAll([term, term]);
    }

    final maps = await db.query(
      'products',
      where: conditions.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'id = ? AND COALESCE(isDeleted, 0) = 0',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<void> createProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(String id) async {
    await _dbHelper.softDeleteProduct(id);
  }

  Future<void> restoreProduct(String id) async {
    await _dbHelper.restoreProduct(id);
  }

  Future<List<Map<String, dynamic>>> getDeletedProducts() async {
    return await _dbHelper.getDeletedProducts();
  }

  Future<void> permanentlyDeleteProduct(String id) async {
    await _dbHelper.permanentlyDeleteProduct(id);
  }
}
