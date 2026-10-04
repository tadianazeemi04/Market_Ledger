import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/presentation/order_providers.dart';

class DashboardMetrics {
  final int todayOrdersCount;
  final double todayOrderValue;
  final double advancesCollected;
  final double pendingBalance;
  final List<OrderModel> recentOrders;

  const DashboardMetrics({
    this.todayOrdersCount = 0,
    this.todayOrderValue = 0.0,
    this.advancesCollected = 0.0,
    this.pendingBalance = 0.0,
    this.recentOrders = const [],
  });
}

final dashboardProvider = FutureProvider<DashboardMetrics>((ref) async {
  // Listen to orderRepositoryProvider
  final orderRepo = ref.watch(orderRepositoryProvider);
  final db = await DatabaseHelper.instance.database;

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

  // 1. Today's orders count & total value
  final todayOrdersResult = await db.rawQuery('''
    SELECT 
      COUNT(*) as count,
      COALESCE(SUM(grandTotal), 0.0) as totalValue
    FROM orders
    WHERE orderDate >= ? AND orderDate <= ? AND COALESCE(isDeleted, 0) = 0
  ''', [startOfToday, endOfToday]);

  final todayCount = (todayOrdersResult.first['count'] as num).toInt();
  final todayValue = (todayOrdersResult.first['totalValue'] as num).toDouble();

  // 2. Advances / payments collected today (excluding deleted orders)
  final todayPaymentsResult = await db.rawQuery('''
    SELECT COALESCE(SUM(p.amount), 0.0) as totalAdvances
    FROM payments p
    LEFT JOIN orders o ON p.orderId = o.id
    WHERE p.paidAt >= ? AND p.paidAt <= ? AND (o.id IS NULL OR COALESCE(o.isDeleted, 0) = 0)
  ''', [startOfToday, endOfToday]);

  final advancesToday = (todayPaymentsResult.first['totalAdvances'] as num).toDouble();

  // 3. Pending balance (sum of balanceAmount of active orders that are not cancelled or deleted)
  final pendingBalanceResult = await db.rawQuery('''
    SELECT COALESCE(SUM(balanceAmount), 0.0) as pendingBalance
    FROM orders
    WHERE status != 'cancelled' AND COALESCE(isDeleted, 0) = 0
  ''');

  final pendingBalance = (pendingBalanceResult.first['pendingBalance'] as num).toDouble();

  // 4. Recent orders (latest 6)
  final recentOrders = await orderRepo.getOrders();
  final topRecent = recentOrders.take(6).toList();

  return DashboardMetrics(
    todayOrdersCount: todayCount,
    todayOrderValue: todayValue,
    advancesCollected: advancesToday,
    pendingBalance: pendingBalance,
    recentOrders: topRecent,
  );
});
