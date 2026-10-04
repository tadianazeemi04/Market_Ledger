import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../constants/enums.dart';

class DatabaseHelper {
  static const String _dbName = 'marketledger.db';
  static const int _dbVersion = 2;

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _ensureColumnsExist(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        shopName TEXT NOT NULL,
        ownerName TEXT NOT NULL,
        phone TEXT,
        marketArea TEXT,
        address TEXT,
        latitude REAL,
        longitude REAL,
        notes TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT,
        unit TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        orderNumber TEXT NOT NULL UNIQUE,
        customerId TEXT NOT NULL,
        orderDate TEXT NOT NULL,
        deliveryDate TEXT,
        status TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discountAmount REAL NOT NULL DEFAULT 0,
        deliveryCharge REAL NOT NULL DEFAULT 0,
        grandTotal REAL NOT NULL,
        advanceAmount REAL NOT NULL DEFAULT 0,
        balanceAmount REAL NOT NULL,
        paymentStatus TEXT NOT NULL,
        notes TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (customerId) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productNameSnapshot TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        discountAmount REAL NOT NULL DEFAULT 0,
        lineTotal REAL NOT NULL,
        FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        referenceNumber TEXT,
        note TEXT,
        paidAt TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        companyName TEXT NOT NULL,
        salespersonName TEXT NOT NULL,
        salespersonPhone TEXT NOT NULL,
        currency TEXT NOT NULL,
        userAge INTEGER,
        isOnboardingCompleted INTEGER NOT NULL DEFAULT 0,
        isDemoAccount INTEGER NOT NULL DEFAULT 0,
        hasSeenWorkflowTour INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_orders_customerId ON orders(customerId);');
    await db.execute('CREATE INDEX idx_orders_orderDate ON orders(orderDate);');
    await db.execute('CREATE INDEX idx_order_items_orderId ON order_items(orderId);');
    await db.execute('CREATE INDEX idx_payments_orderId ON payments(orderId);');

    // Fresh install starts with a clean empty settings record, NO dummy data!
    await db.insert('settings', {
      'id': 1,
      'companyName': '',
      'salespersonName': '',
      'salespersonPhone': '',
      'currency': 'PKR (Rs.)',
      'userAge': null,
      'isOnboardingCompleted': 0,
      'isDemoAccount': 0,
      'hasSeenWorkflowTour': 0,
    });

    // Account stash table and saved accounts table for multi-account management
    await _ensureSavedAccountsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureColumnsExist(db);
  }

  Future<void> _ensureStashTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_account_stash (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        snapshotJson TEXT NOT NULL,
        salespersonName TEXT NOT NULL,
        companyName TEXT NOT NULL,
        savedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureSavedAccountsTable(DatabaseExecutor db) async {
    await _ensureStashTable(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_accounts (
        id TEXT PRIMARY KEY,
        salespersonName TEXT NOT NULL,
        companyName TEXT NOT NULL,
        salespersonPhone TEXT NOT NULL DEFAULT '',
        userAge INTEGER,
        currency TEXT NOT NULL DEFAULT 'PKR (Rs.)',
        createdAt TEXT NOT NULL,
        lastActiveAt TEXT NOT NULL,
        snapshotJson TEXT NOT NULL
      )
    ''');

    // Auto-migrate legacy user_account_stash into saved_accounts if present
    try {
      final stashRows = await db.query('user_account_stash', limit: 1);
      if (stashRows.isNotEmpty) {
        final row = stashRows.first;
        final name = row['salespersonName'] as String? ?? '';
        final company = row['companyName'] as String? ?? '';
        final snapshot = row['snapshotJson'] as String? ?? '';
        final savedAt = row['savedAt'] as String? ?? DateTime.now().toIso8601String();
        if (name.isNotEmpty && company.isNotEmpty && snapshot.isNotEmpty) {
          final id = 'acc_${company.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
          await db.insert('saved_accounts', {
            'id': id,
            'salespersonName': name,
            'companyName': company,
            'salespersonPhone': '',
            'userAge': null,
            'currency': 'PKR (Rs.)',
            'createdAt': savedAt,
            'lastActiveAt': savedAt,
            'snapshotJson': snapshot,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureColumnsExist(Database db) async {
    Future<void> addCol(String table, String colDef) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $colDef;');
      } catch (_) {
        // column might already exist
      }
    }

    await addCol('customers', 'isDeleted INTEGER NOT NULL DEFAULT 0');
    await addCol('customers', 'deletedAt TEXT');

    await addCol('products', 'isDeleted INTEGER NOT NULL DEFAULT 0');
    await addCol('products', 'deletedAt TEXT');

    await addCol('orders', 'isDeleted INTEGER NOT NULL DEFAULT 0');
    await addCol('orders', 'deletedAt TEXT');

    await addCol('settings', 'userAge INTEGER');
    await addCol('settings', 'isOnboardingCompleted INTEGER NOT NULL DEFAULT 0');
    await addCol('settings', 'isDemoAccount INTEGER NOT NULL DEFAULT 0');
    await addCol('settings', 'hasSeenWorkflowTour INTEGER NOT NULL DEFAULT 0');

    await _ensureSavedAccountsTable(db);
  }

  Future<void> _seedInitialData(DatabaseExecutor db, {bool isDemo = true}) async {
    final now = DateTime.now();
    const uuid = Uuid();

    // 1. Settings
    await db.insert('settings', {
      'id': 1,
      'companyName': isDemo ? 'Global Wholesale Traders' : 'Alpha Wholesale Distributors',
      'salespersonName': isDemo ? 'Apple App Store Reviewer' : 'Tariq Mehmood',
      'salespersonPhone': isDemo ? '+1 408 996 1010' : '+92 300 1234567',
      'currency': 'PKR (Rs.)',
      'userAge': isDemo ? 30 : 35,
      'isOnboardingCompleted': isDemo ? 1 : 0,
      'isDemoAccount': isDemo ? 1 : 0,
      'hasSeenWorkflowTour': isDemo ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 2. Realistic wholesale products
    final products = [
      {'name': 'Habib Cooking Oil 5L', 'sku': 'OIL-005', 'unit': 'Tin', 'price': 2650.0},
      {'name': 'Super Basmati Rice 25kg', 'sku': 'RCE-025', 'unit': 'Bag', 'price': 7400.0},
      {'name': 'White Refined Sugar 50kg', 'sku': 'SGR-050', 'unit': 'Bag', 'price': 6900.0},
      {'name': 'Tapal Danedar Tea 900g', 'sku': 'TEA-900', 'unit': 'Box', 'price': 1480.0},
      {'name': 'Mehran Chakki Atta 20kg', 'sku': 'FLR-020', 'unit': 'Bag', 'price': 2550.0},
      {'name': 'Dalda Banaspati Ghee 1kg x 5', 'sku': 'GHE-005', 'unit': 'Carton', 'price': 2750.0},
      {'name': 'National Spices Mix Carton', 'sku': 'SPC-012', 'unit': 'Carton', 'price': 3200.0},
      {'name': 'Surf Excel 1kg x 12', 'sku': 'DET-012', 'unit': 'Carton', 'price': 4600.0},
      {'name': 'Lux Soap 140g x 48', 'sku': 'SOP-048', 'unit': 'Carton', 'price': 5200.0},
      {'name': 'Aquafina Water 1.5L x 6', 'sku': 'WTR-006', 'unit': 'Pack', 'price': 650.0},
      {'name': 'Olper\'s Milk 1L x 12', 'sku': 'MLK-012', 'unit': 'Carton', 'price': 3360.0},
      {'name': 'Mitchell\'s Jam 450g x 12', 'sku': 'JAM-012', 'unit': 'Carton', 'price': 2950.0},
    ];

    final productIds = <String>[];
    for (final p in products) {
      final pid = uuid.v4();
      productIds.add(pid);
      await db.insert('products', {
        'id': pid,
        'name': p['name'],
        'sku': p['sku'],
        'unit': p['unit'],
        'unitPrice': p['price'],
        'isActive': 1,
        'isDeleted': 0,
        'deletedAt': null,
        'createdAt': now.subtract(const Duration(days: 30)).toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    }

    // 3. Customers
    final customers = [
      {
        'id': 'c1',
        'shopName': 'Madina Karyana Store',
        'ownerName': 'Muhammad Imran',
        'phone': '0300-5551234',
        'marketArea': 'Main Bazaar',
        'address': 'Shop #14, Main Bazaar, Lahore',
        'latitude': 31.5204,
        'longitude': 74.3587,
        'notes': 'Preferred delivery in morning before 11 AM.',
      },
      {
        'id': 'c2',
        'shopName': 'Al-Rehman General Traders',
        'ownerName': 'Tariq Javed',
        'phone': '0321-4442345',
        'marketArea': 'Anarkali Market',
        'address': '24 Circular Road, Lahore',
        'latitude': 31.5712,
        'longitude': 74.3120,
        'notes': 'Requires GST sales tax invoice copy.',
      },
      {
        'id': 'c3',
        'shopName': 'Bismillah Super Mart',
        'ownerName': 'Haji Abdul Ghaffar',
        'phone': '0333-8889911',
        'marketArea': 'Shah Alam Market',
        'address': 'Shah Alam Gate, Lahore',
        'latitude': 31.5831,
        'longitude': 74.3211,
        'notes': 'Large wholesale buyer. High turnover on sugar and rice.',
      },
      {
        'id': 'c4',
        'shopName': 'Subhan Wholesale Point',
        'ownerName': 'Kamran Akram',
        'phone': '0312-7776655',
        'marketArea': 'Urdu Bazaar',
        'address': 'Shop 5, Urdu Bazaar, Lahore',
        'latitude': 31.5744,
        'longitude': 74.3155,
        'notes': 'Weekly settlement every Saturday.',
      },
      {
        'id': 'c5',
        'shopName': 'Khyber Grocery Corner',
        'ownerName': 'Gul Khan',
        'phone': '0345-6663322',
        'marketArea': 'Ichhra Market',
        'address': 'Ferozepur Road, Ichhra, Lahore',
        'latitude': 31.5173,
        'longitude': 74.3245,
        'notes': 'Cash on delivery preferred.',
      },
    ];

    for (final c in customers) {
      await db.insert('customers', {
        'id': c['id'],
        'shopName': c['shopName'],
        'ownerName': c['ownerName'],
        'phone': c['phone'],
        'marketArea': c['marketArea'],
        'address': c['address'],
        'latitude': c['latitude'],
        'longitude': c['longitude'],
        'notes': c['notes'],
        'isDeleted': 0,
        'deletedAt': null,
        'createdAt': now.subtract(const Duration(days: 20)).toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    }

    // 4. Sample Orders & Order Items & Payments
    final order1Id = uuid.v4();
    final todayOrderDate = DateTime(now.year, now.month, now.day, 10, 30);
    await db.insert('orders', {
      'id': order1Id,
      'orderNumber': 'ML-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-001',
      'customerId': 'c1',
      'orderDate': todayOrderDate.toIso8601String(),
      'deliveryDate': todayOrderDate.add(const Duration(days: 1)).toIso8601String(),
      'status': OrderStatus.confirmed.name,
      'subtotal': 33500.0,
      'discountAmount': 500.0,
      'deliveryCharge': 200.0,
      'grandTotal': 33200.0,
      'advanceAmount': 15000.0,
      'balanceAmount': 18200.0,
      'paymentStatus': PaymentStatus.partial.name,
      'notes': 'Deliver early morning before rush hour.',
      'isDeleted': 0,
      'deletedAt': null,
      'createdAt': todayOrderDate.toIso8601String(),
      'updatedAt': todayOrderDate.toIso8601String(),
    });

    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order1Id,
      'productId': productIds[1],
      'productNameSnapshot': 'Super Basmati Rice 25kg',
      'quantity': 3.0,
      'unit': 'Bag',
      'unitPrice': 7400.0,
      'discountAmount': 0.0,
      'lineTotal': 22200.0,
    });
    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order1Id,
      'productId': productIds[8],
      'productNameSnapshot': 'Lux Soap 140g x 48',
      'quantity': 2.0,
      'unit': 'Carton',
      'unitPrice': 5200.0,
      'discountAmount': 0.0,
      'lineTotal': 10400.0,
    });
    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order1Id,
      'productId': productIds[9],
      'productNameSnapshot': 'Aquafina Water 1.5L x 6',
      'quantity': 2.0,
      'unit': 'Pack',
      'unitPrice': 650.0,
      'discountAmount': 0.0,
      'lineTotal': 1300.0,
    });

    await db.insert('payments', {
      'id': uuid.v4(),
      'orderId': order1Id,
      'amount': 15000.0,
      'method': PaymentMethod.cash.name,
      'referenceNumber': 'CSH-091',
      'note': 'Advance cash received during booking.',
      'paidAt': todayOrderDate.toIso8601String(),
      'createdAt': todayOrderDate.toIso8601String(),
    });

    // Order 2: Today, Al-Rehman General Traders (Delivered, Paid)
    final order2Id = uuid.v4();
    final todayOrderDate2 = DateTime(now.year, now.month, now.day, 11, 45);
    await db.insert('orders', {
      'id': order2Id,
      'orderNumber': 'ML-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-002',
      'customerId': 'c2',
      'orderDate': todayOrderDate2.toIso8601String(),
      'deliveryDate': todayOrderDate2.toIso8601String(),
      'status': OrderStatus.delivered.name,
      'subtotal': 19500.0,
      'discountAmount': 0.0,
      'deliveryCharge': 0.0,
      'grandTotal': 19500.0,
      'advanceAmount': 19500.0,
      'balanceAmount': 0.0,
      'paymentStatus': PaymentStatus.paid.name,
      'notes': 'Paid via direct bank transfer and delivered on spot.',
      'isDeleted': 0,
      'deletedAt': null,
      'createdAt': todayOrderDate2.toIso8601String(),
      'updatedAt': todayOrderDate2.toIso8601String(),
    });

    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order2Id,
      'productId': productIds[0],
      'productNameSnapshot': 'Habib Cooking Oil 5L',
      'quantity': 5.0,
      'unit': 'Tin',
      'unitPrice': 2650.0,
      'discountAmount': 0.0,
      'lineTotal': 13250.0,
    });
    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order2Id,
      'productId': productIds[6],
      'productNameSnapshot': 'National Spices Mix Carton',
      'quantity': 2.0,
      'unit': 'Carton',
      'unitPrice': 3200.0,
      'discountAmount': 150.0,
      'lineTotal': 6250.0,
    });

    await db.insert('payments', {
      'id': uuid.v4(),
      'orderId': order2Id,
      'amount': 19500.0,
      'method': PaymentMethod.bankTransfer.name,
      'referenceNumber': 'FT-889021-HBL',
      'note': 'Full amount transferred to Meezan Bank.',
      'paidAt': todayOrderDate2.toIso8601String(),
      'createdAt': todayOrderDate2.toIso8601String(),
    });

    // Order 3: Yesterday, Bismillah Super Mart (Processing, Partial)
    final order3Id = uuid.v4();
    final yesterdayDate = now.subtract(const Duration(days: 1));
    await db.insert('orders', {
      'id': order3Id,
      'orderNumber': 'ML-${yesterdayDate.year}${yesterdayDate.month.toString().padLeft(2, '0')}${yesterdayDate.day.toString().padLeft(2, '0')}-001',
      'customerId': 'c3',
      'orderDate': yesterdayDate.toIso8601String(),
      'deliveryDate': now.add(const Duration(days: 1)).toIso8601String(),
      'status': OrderStatus.processing.name,
      'subtotal': 42000.0,
      'discountAmount': 1000.0,
      'deliveryCharge': 500.0,
      'grandTotal': 41500.0,
      'advanceAmount': 20000.0,
      'balanceAmount': 21500.0,
      'paymentStatus': PaymentStatus.partial.name,
      'notes': 'Loading arranged from main warehouse.',
      'isDeleted': 0,
      'deletedAt': null,
      'createdAt': yesterdayDate.toIso8601String(),
      'updatedAt': yesterdayDate.toIso8601String(),
    });

    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order3Id,
      'productId': productIds[2],
      'productNameSnapshot': 'White Refined Sugar 50kg',
      'quantity': 5.0,
      'unit': 'Bag',
      'unitPrice': 6900.0,
      'discountAmount': 0.0,
      'lineTotal': 34500.0,
    });
    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order3Id,
      'productId': productIds[4],
      'productNameSnapshot': 'Mehran Chakki Atta 20kg',
      'quantity': 3.0,
      'unit': 'Bag',
      'unitPrice': 2550.0,
      'discountAmount': 150.0,
      'lineTotal': 7500.0,
    });

    await db.insert('payments', {
      'id': uuid.v4(),
      'orderId': order3Id,
      'amount': 20000.0,
      'method': PaymentMethod.mobileWallet.name,
      'referenceNumber': 'JC-9021882',
      'note': 'JazzCash advance payment received.',
      'paidAt': yesterdayDate.toIso8601String(),
      'createdAt': yesterdayDate.toIso8601String(),
    });

    // Order 4: 2 Days ago, Subhan Wholesale Point (Draft, Unpaid)
    final order4Id = uuid.v4();
    final twoDaysAgoDate = now.subtract(const Duration(days: 2));
    await db.insert('orders', {
      'id': order4Id,
      'orderNumber': 'ML-${twoDaysAgoDate.year}${twoDaysAgoDate.month.toString().padLeft(2, '0')}${twoDaysAgoDate.day.toString().padLeft(2, '0')}-001',
      'customerId': 'c4',
      'orderDate': twoDaysAgoDate.toIso8601String(),
      'status': OrderStatus.draft.name,
      'subtotal': 14800.0,
      'discountAmount': 0.0,
      'deliveryCharge': 0.0,
      'grandTotal': 14800.0,
      'advanceAmount': 0.0,
      'balanceAmount': 14800.0,
      'paymentStatus': PaymentStatus.unpaid.name,
      'notes': 'Customer requested quotation first, pending final confirmation.',
      'isDeleted': 0,
      'deletedAt': null,
      'createdAt': twoDaysAgoDate.toIso8601String(),
      'updatedAt': twoDaysAgoDate.toIso8601String(),
    });

    await db.insert('order_items', {
      'id': uuid.v4(),
      'orderId': order4Id,
      'productId': productIds[3],
      'productNameSnapshot': 'Tapal Danedar Tea 900g',
      'quantity': 10.0,
      'unit': 'Box',
      'unitPrice': 1480.0,
      'discountAmount': 0.0,
      'lineTotal': 14800.0,
    });
  }

  /// Setup Clean User Account: wipes all dummy/sample data completely so the
  /// real user starts fresh with 0 orders, 0 shops, and 0 products.
  /// Setup Clean User Account: wipes active tables so the salesperson starts
  /// fresh with 0 orders, 0 shops, and 0 products, while preserving any
  /// other previously saved accounts.
  Future<void> setupCleanUserAccount({
    required String name,
    required String company,
    required int? age,
    String? phone,
  }) async {
    final db = await database;
    await _ensureSavedAccountsTable(db);

    // Preserve previously active account if genuine user profile
    await snapshotCurrentAccount();

    // Validate that company name is unique across all existing accounts
    final isTaken = await isCompanyNameTaken(company, excludeActiveAccount: false);
    if (isTaken) {
      throw Exception(
        'A company named "$company" already exists. Please choose a unique company name.',
      );
    }

    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('customers');
      await txn.delete('products');
      await txn.insert('settings', {
        'id': 1,
        'companyName': company,
        'salespersonName': name,
        'salespersonPhone': phone ?? '',
        'currency': 'PKR (Rs.)',
        'userAge': age,
        'isOnboardingCompleted': 1,
        'isDemoAccount': 0,
        'hasSeenWorkflowTour': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    // Save this new active account to saved_accounts
    await snapshotCurrentAccount();
  }

  /// Setup Demo Review Account for Apple Review team or testing.
  /// Automatically snapshots current user account into saved_accounts
  /// so it can be restored anytime with zero data loss.
  Future<void> setupDemoAccount() async {
    final db = await database;
    await _ensureSavedAccountsTable(db);

    // Snapshot currently active account first
    await snapshotCurrentAccount();

    // Wipe live tables and seed demo data
    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('customers');
      await txn.delete('products');
      await txn.delete('settings');
      await _seedInitialData(txn, isDemo: true);
    });
  }

  /// Checks if a company name is already registered in saved_accounts or active settings
  Future<bool> isCompanyNameTaken(
    String companyName, {
    String? excludeAccountId,
    String? excludeCompanyName,
    bool excludeActiveAccount = false,
  }) async {
    final trimmed = companyName.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    try {
      final db = await database;
      await _ensureSavedAccountsTable(db);

      final excludeCompTrimmed = excludeCompanyName?.trim().toLowerCase();

      // 1. Check in saved_accounts
      final saved = await db.query('saved_accounts');
      for (final row in saved) {
        if (excludeAccountId != null && row['id'] == excludeAccountId) {
          continue;
        }
        final existingCompany =
            (row['companyName'] as String? ?? '').trim().toLowerCase();
        if (excludeCompTrimmed != null && existingCompany == excludeCompTrimmed) {
          continue;
        }
        if (existingCompany == trimmed) {
          return true;
        }
      }

      // 2. Check in active settings
      if (!excludeActiveAccount) {
        final activeSettings =
            await db.query('settings', where: 'id = 1', limit: 1);
        if (activeSettings.isNotEmpty) {
          final s = activeSettings.first;
          final isDemo = (s['isDemoAccount'] as int?) == 1;
          final activeCompany =
              (s['companyName'] as String? ?? '').trim().toLowerCase();
          if (excludeCompTrimmed != null && activeCompany == excludeCompTrimmed) {
            // excluded
          } else if (!isDemo && activeCompany == trimmed) {
            return true;
          }
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Takes complete JSON snapshot of currently active account and registers/updates it in saved_accounts
  Future<String?> snapshotCurrentAccount() async {
    try {
      final db = await database;
      await _ensureSavedAccountsTable(db);

      final currentSettings =
          await db.query('settings', where: 'id = 1', limit: 1);
      if (currentSettings.isEmpty) return null;

      final s = currentSettings.first;
      final isDemo = (s['isDemoAccount'] as int?) == 1;
      final isOnboardingCompleted = (s['isOnboardingCompleted'] as int?) == 1;
      final name = (s['salespersonName'] as String?)?.trim() ?? '';
      final company = (s['companyName'] as String?)?.trim() ?? '';

      if (isDemo || !isOnboardingCompleted || name.isEmpty || company.isEmpty) {
        return null;
      }

      // Find if this account is already registered in saved_accounts
      final existing = await db.query(
        'saved_accounts',
        where: 'LOWER(TRIM(companyName)) = ?',
        whereArgs: [company.toLowerCase()],
        limit: 1,
      );

      final accountId = existing.isNotEmpty
          ? existing.first['id'] as String
          : const Uuid().v4();

      final now = DateTime.now().toIso8601String();
      final createdAt = existing.isNotEmpty
          ? existing.first['createdAt'] as String? ?? now
          : now;

      final snapshot = await exportAllDataAsJson(includeDeleted: true);
      final snapshotJson = jsonEncode(snapshot);

      await db.insert(
        'saved_accounts',
        {
          'id': accountId,
          'salespersonName': name,
          'companyName': company,
          'salespersonPhone': s['salespersonPhone'] as String? ?? '',
          'userAge': s['userAge'],
          'currency': s['currency'] as String? ?? 'PKR (Rs.)',
          'createdAt': createdAt,
          'lastActiveAt': now,
          'snapshotJson': snapshotJson,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return accountId;
    } catch (_) {
      return null;
    }
  }

  /// Returns list of all saved accounts sorted by last active
  Future<List<Map<String, dynamic>>> getAllSavedAccounts() async {
    try {
      final db = await database;
      await _ensureSavedAccountsTable(db);
      return await db.query('saved_accounts', orderBy: 'lastActiveAt DESC');
    } catch (_) {
      return [];
    }
  }

  /// Switches active database tables to the target saved account
  Future<bool> switchToSavedAccount(String accountId) async {
    try {
      final db = await database;
      await _ensureSavedAccountsTable(db);

      final targetRows = await db.query(
        'saved_accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (targetRows.isEmpty) return false;

      // 1. Snapshot active account first so no edits are lost
      await snapshotCurrentAccount();

      final targetRow = targetRows.first;
      final rawJson = targetRow['snapshotJson'] as String;
      final data = jsonDecode(rawJson) as Map<String, dynamic>;

      await db.transaction((txn) async {
        await txn.delete('payments');
        await txn.delete('order_items');
        await txn.delete('orders');
        await txn.delete('customers');
        await txn.delete('products');
        await txn.delete('settings');

        // Restore settings
        if (data['settings'] != null) {
          final settingsMap =
              Map<String, dynamic>.from(data['settings'] as Map);
          settingsMap['isDemoAccount'] = 0;
          settingsMap['isOnboardingCompleted'] = 1;
          await txn.insert(
            'settings',
            settingsMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Restore customers
        if (data['customers'] is List) {
          for (final c in (data['customers'] as List)) {
            await txn.insert(
              'customers',
              Map<String, dynamic>.from(c as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Restore products
        if (data['products'] is List) {
          for (final p in (data['products'] as List)) {
            await txn.insert(
              'products',
              Map<String, dynamic>.from(p as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Restore orders
        if (data['orders'] is List) {
          for (final o in (data['orders'] as List)) {
            await txn.insert(
              'orders',
              Map<String, dynamic>.from(o as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Restore order_items
        if (data['order_items'] is List) {
          for (final item in (data['order_items'] as List)) {
            await txn.insert(
              'order_items',
              Map<String, dynamic>.from(item as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Restore payments
        if (data['payments'] is List) {
          for (final pay in (data['payments'] as List)) {
            await txn.insert(
              'payments',
              Map<String, dynamic>.from(pay as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Update lastActiveAt in saved_accounts
        await txn.update(
          'saved_accounts',
          {'lastActiveAt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Permanently delete a saved account
  Future<void> deleteSavedAccount(String accountId) async {
    final db = await database;
    await _ensureSavedAccountsTable(db);
    await db.delete('saved_accounts', where: 'id = ?', whereArgs: [accountId]);
  }

  /// Checks if any saved custom user account exists
  Future<bool> hasSavedUserAccount() async {
    final accounts = await getAllSavedAccounts();
    return accounts.isNotEmpty;
  }

  /// Gets preview details of the most recently active saved user account
  Future<Map<String, dynamic>?> getSavedUserProfile() async {
    final accounts = await getAllSavedAccounts();
    if (accounts.isEmpty) return null;
    return accounts.first;
  }

  /// Restores the most recently active user account
  Future<bool> restoreUserAccountFromStash() async {
    final accounts = await getAllSavedAccounts();
    if (accounts.isEmpty) return false;
    return await switchToSavedAccount(accounts.first['id'] as String);
  }

  /// Clears user account stash & saved accounts
  Future<void> clearUserAccountStash() async {
    final db = await database;
    await _ensureSavedAccountsTable(db);
    await db.delete('user_account_stash');
    await db.delete('saved_accounts');
  }

  /// Leave Demo Account and return to clean custom setup (wiping demo records).
  Future<void> leaveDemoAccount({bool clearStash = false}) async {
    final db = await database;
    await _ensureSavedAccountsTable(db);
    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('customers');
      await txn.delete('products');
      if (clearStash) {
        await txn.delete('user_account_stash');
        await txn.delete('saved_accounts');
      }
      await txn.update('settings', {
        'companyName': '',
        'salespersonName': '',
        'salespersonPhone': '',
        'isDemoAccount': 0,
        'isOnboardingCompleted': 0,
        'hasSeenWorkflowTour': 0,
      }, where: 'id = 1');
    });
  }

  /// Mark workflow tour as completed
  Future<void> markWorkflowTourSeen() async {
    final db = await database;
    await db.update('settings', {'hasSeenWorkflowTour': 1}, where: 'id = 1');
  }

  /// Soft Delete Helpers
  Future<void> softDeleteCustomer(String id) async {
    final db = await database;
    await db.update(
      'customers',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreCustomer(String id) async {
    final db = await database;
    await db.update(
      'customers',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedCustomers() async {
    final db = await database;
    return await db.query('customers', where: 'isDeleted = 1', orderBy: 'deletedAt DESC');
  }

  Future<void> permanentlyDeleteCustomer(String id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> softDeleteOrder(String id) async {
    final db = await database;
    await db.update(
      'orders',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreOrder(String id) async {
    final db = await database;
    await db.update(
      'orders',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedOrders() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT o.*, c.shopName as c_shopName, c.ownerName as c_ownerName
      FROM orders o
      LEFT JOIN customers c ON o.customerId = c.id
      WHERE o.isDeleted = 1
      ORDER BY o.deletedAt DESC
    ''');
  }

  Future<void> permanentlyDeleteOrder(String id) async {
    final db = await database;
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> softDeleteProduct(String id) async {
    final db = await database;
    await db.update(
      'products',
      {'isDeleted': 1, 'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreProduct(String id) async {
    final db = await database;
    await db.update(
      'products',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedProducts() async {
    final db = await database;
    return await db.query('products', where: 'isDeleted = 1', orderBy: 'deletedAt DESC');
  }

  Future<void> permanentlyDeleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Reset all data back to clean initial demo data state.
  Future<void> resetToDemoData() async {
    await setupDemoAccount();
  }

  /// Exports entire database as structured JSON map.
  Future<Map<String, dynamic>> exportAllDataAsJson({bool includeDeleted = false}) async {
    final db = await database;
    final customers = await db.query(
      'customers',
      where: includeDeleted ? null : 'isDeleted = 0',
    );
    final products = await db.query(
      'products',
      where: includeDeleted ? null : 'isDeleted = 0',
    );
    final orders = await db.query(
      'orders',
      where: includeDeleted ? null : 'isDeleted = 0',
    );
    final orderItems = await db.query('order_items');
    final payments = await db.query('payments');
    final settings = await db.query('settings');

    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.isNotEmpty ? settings.first : null,
      'customers': customers,
      'products': products,
      'orders': orders,
      'order_items': orderItems,
      'payments': payments,
    };
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
