import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/saved_account_model.dart';
import '../domain/settings_model.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper;

  SettingsRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<AppSettings> getSettings() async {
    final db = await _dbHelper.database;
    final maps = await db.query('settings', where: 'id = 1', limit: 1);
    if (maps.isNotEmpty) {
      return AppSettings.fromMap(maps.first);
    }
    return const AppSettings();
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await _dbHelper.database;
    await db.insert(
      'settings',
      {'id': 1, ...settings.toMap()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> resetToDemoData() async {
    await _dbHelper.resetToDemoData();
  }

  Future<void> markWorkflowTourSeen() async {
    await _dbHelper.markWorkflowTourSeen();
  }

  Future<List<SavedAccount>> getSavedAccounts() async {
    final rows = await _dbHelper.getAllSavedAccounts();
    return rows.map((r) => SavedAccount.fromMap(r)).toList();
  }

  Future<bool> isCompanyNameTaken(
    String companyName, {
    String? excludeAccountId,
    String? excludeCompanyName,
    bool excludeActiveAccount = false,
  }) async {
    return await _dbHelper.isCompanyNameTaken(
      companyName,
      excludeAccountId: excludeAccountId,
      excludeCompanyName: excludeCompanyName,
      excludeActiveAccount: excludeActiveAccount,
    );
  }

  Future<bool> switchToSavedAccount(String accountId) async {
    return await _dbHelper.switchToSavedAccount(accountId);
  }

  Future<void> deleteSavedAccount(String accountId) async {
    await _dbHelper.deleteSavedAccount(accountId);
  }

  Future<void> snapshotCurrentAccount() async {
    await _dbHelper.snapshotCurrentAccount();
  }

  Future<bool> hasSavedUserAccount() async {
    return await _dbHelper.hasSavedUserAccount();
  }

  Future<Map<String, dynamic>?> getSavedUserProfile() async {
    return await _dbHelper.getSavedUserProfile();
  }

  Future<bool> restoreUserAccountFromStash() async {
    return await _dbHelper.restoreUserAccountFromStash();
  }

  Future<void> clearUserAccountStash() async {
    await _dbHelper.clearUserAccountStash();
  }

  Future<void> leaveDemoAccount({bool clearStash = false}) async {
    await _dbHelper.leaveDemoAccount(clearStash: clearStash);
  }

  Future<void> setupCleanUserAccount({
    required String name,
    required String company,
    required int? age,
    String? phone,
  }) async {
    await _dbHelper.setupCleanUserAccount(
      name: name,
      company: company,
      age: age,
      phone: phone,
    );
  }

  Future<String> exportAsJsonString() async {
    final data = await _dbHelper.exportAllDataAsJson();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> exportCustomersAsCsv() async {
    final db = await _dbHelper.database;
    final customers = await db.query('customers', orderBy: 'shopName ASC');
    final buffer = StringBuffer();
    buffer.writeln('ID,Shop Name,Owner Name,Phone,Market Area,Address,Latitude,Longitude,Notes,Created At');
    for (final c in customers) {
      buffer.writeln(
        '"${c['id']}","${c['shopName']}","${c['ownerName']}","${c['phone']}","${c['marketArea']}","${(c['address'] as String?)?.replaceAll('"', '""') ?? ''}","${c['latitude'] ?? ''}","${c['longitude'] ?? ''}","${(c['notes'] as String?)?.replaceAll('"', '""') ?? ''}","${c['createdAt']}"',
      );
    }
    return buffer.toString();
  }

  Future<String> exportOrdersAsCsv() async {
    final db = await _dbHelper.database;
    final orders = await db.rawQuery('''
      SELECT o.*, c.shopName, c.ownerName 
      FROM orders o
      LEFT JOIN customers c ON o.customerId = c.id
      ORDER BY o.orderDate DESC
    ''');
    final buffer = StringBuffer();
    buffer.writeln('Order Number,Date,Shop Name,Owner Name,Status,Subtotal,Discount,Delivery,Grand Total,Advance Paid,Balance,Payment Status,Notes');
    for (final o in orders) {
      buffer.writeln(
        '"${o['orderNumber']}","${o['orderDate']}","${o['shopName']}","${o['ownerName']}","${o['status']}","${o['subtotal']}","${o['discountAmount']}","${o['deliveryCharge']}","${o['grandTotal']}","${o['advanceAmount']}","${o['balanceAmount']}","${o['paymentStatus']}","${(o['notes'] as String?)?.replaceAll('"', '""') ?? ''}"',
      );
    }
    return buffer.toString();
  }
}
