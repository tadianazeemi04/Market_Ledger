import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../../orders/presentation/order_providers.dart';
import '../../products/presentation/product_providers.dart';

class DataRecoveryScreen extends ConsumerStatefulWidget {
  const DataRecoveryScreen({super.key});

  @override
  ConsumerState<DataRecoveryScreen> createState() => _DataRecoveryScreenState();
}

class _DataRecoveryScreenState extends ConsumerState<DataRecoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _deletedOrders = [];
  List<Map<String, dynamic>> _deletedCustomers = [];
  List<Map<String, dynamic>> _deletedProducts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDeletedData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedData() async {
    setState(() => _isLoading = true);
    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final customerRepo = ref.read(customerRepositoryProvider);
      final productRepo = ref.read(productRepositoryProvider);

      final results = await Future.wait([
        orderRepo.getDeletedOrders(),
        customerRepo.getDeletedCustomers(),
        productRepo.getDeletedProducts(),
      ]);

      if (mounted) {
        setState(() {
          _deletedOrders = results[0];
          _deletedCustomers = results[1];
          _deletedProducts = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trash: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreOrder(String id, String orderNumber) async {
    try {
      final repo = ref.read(orderRepositoryProvider);
      await repo.restoreOrder(id);
      ref.invalidate(orderListProvider);
      ref.invalidate(dashboardProvider);
      await _loadDeletedData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order "$orderNumber" restored successfully!'),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore order: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteOrder(String id, String orderNumber) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Permanently Delete Order?',
      message:
          'This will permanently remove order "$orderNumber" from your device. This cannot be undone.',
      confirmLabel: 'Delete Forever',
      confirmColor: AppColors.errorRed,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed && mounted) {
      final repo = ref.read(orderRepositoryProvider);
      await repo.permanentlyDeleteOrder(id);
      await _loadDeletedData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order "$orderNumber" permanently deleted.'),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreCustomer(String id, String shopName) async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.restoreCustomer(id);
      ref.invalidate(customerListProvider);
      ref.invalidate(dashboardProvider);
      await _loadDeletedData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shop "$shopName" restored successfully!'),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore shop: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteCustomer(String id, String shopName) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Permanently Delete Shop?',
      message:
          'This will permanently remove "$shopName" from your device. Orders linked to this shop will lose their customer profile.',
      confirmLabel: 'Delete Forever',
      confirmColor: AppColors.errorRed,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed && mounted) {
      final repo = ref.read(customerRepositoryProvider);
      await repo.permanentlyDeleteCustomer(id);
      await _loadDeletedData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shop "$shopName" permanently deleted.'),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreProduct(String id, String name) async {
    try {
      final repo = ref.read(productRepositoryProvider);
      await repo.restoreProduct(id);
      ref.invalidate(productListProvider);
      await _loadDeletedData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "$name" restored successfully!'),
            backgroundColor: AppColors.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore product: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteProduct(String id, String name) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Permanently Delete Product?',
      message:
          'This will permanently remove product "$name" from your catalog.',
      confirmLabel: 'Delete Forever',
      confirmColor: AppColors.errorRed,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed && mounted) {
      final repo = ref.read(productRepositoryProvider);
      await repo.permanentlyDeleteProduct(id);
      await _loadDeletedData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "$name" permanently deleted.'),
            backgroundColor: AppColors.primaryNavy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildDeletedOrdersTab() {
    if (_deletedOrders.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Deleted Orders',
        message:
            'Orders you delete will appear here so you can easily recover them anytime.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedOrders.length,
      itemBuilder: (context, index) {
        final order = _deletedOrders[index];
        final orderId = order['id'] as String;
        final orderNumber = order['orderNumber'] as String? ?? 'Order';
        final shopName = order['c_shopName'] as String? ?? 'Unknown Shop';
        final grandTotal = (order['grandTotal'] as num?)?.toDouble() ?? 0.0;
        final deletedAt = order['deletedAt'] != null
            ? DateTime.tryParse(order['deletedAt'] as String)
            : null;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      orderNumber,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(grandTotal),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Shop: $shopName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (deletedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Deleted: ${DateFormatter.formatDateTime(deletedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _permanentlyDeleteOrder(orderId, orderNumber),
                      icon: const Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.errorRed),
                      label: const Text('Delete Forever', style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _restoreOrder(orderId, orderNumber),
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('Restore', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldGreen,
                        minimumSize: const Size(90, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeletedCustomersTab() {
    if (_deletedCustomers.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Deleted Shops',
        message:
            'Shops or customers you remove can be restored back to your client directory here.',
        icon: Icons.storefront_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedCustomers.length,
      itemBuilder: (context, index) {
        final cust = _deletedCustomers[index];
        final id = cust['id'] as String;
        final shopName = cust['shopName'] as String? ?? 'Unnamed Shop';
        final ownerName = cust['ownerName'] as String? ?? '';
        final area = cust['marketArea'] as String? ?? '';
        final deletedAt = cust['deletedAt'] != null
            ? DateTime.tryParse(cust['deletedAt'] as String)
            : null;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Owner: $ownerName ${area.isNotEmpty ? "• $area" : ""}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (deletedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Deleted: ${DateFormatter.formatDateTime(deletedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _permanentlyDeleteCustomer(id, shopName),
                      icon: const Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.errorRed),
                      label: const Text('Delete Forever', style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _restoreCustomer(id, shopName),
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('Restore', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldGreen,
                        minimumSize: const Size(90, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeletedProductsTab() {
    if (_deletedProducts.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Deleted Products',
        message:
            'Products removed from your catalog can be restored back anytime.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedProducts.length,
      itemBuilder: (context, index) {
        final prod = _deletedProducts[index];
        final id = prod['id'] as String;
        final name = prod['name'] as String? ?? 'Unnamed Product';
        final unit = prod['unit'] as String? ?? 'Unit';
        final price = (prod['unitPrice'] as num?)?.toDouble() ?? 0.0;
        final deletedAt = prod['deletedAt'] != null
            ? DateTime.tryParse(prod['deletedAt'] as String)
            : null;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ),
                    Text(
                      '${CurrencyFormatter.format(price)} / $unit',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                if (deletedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Deleted: ${DateFormatter.formatDateTime(deletedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _permanentlyDeleteProduct(id, name),
                      icon: const Icon(Icons.delete_forever_rounded, size: 16, color: AppColors.errorRed),
                      label: const Text('Delete Forever', style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _restoreProduct(id, name),
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('Restore', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldGreen,
                        minimumSize: const Size(90, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Deleted Data'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          indicatorColor: AppColors.amberAccent,
          tabs: [
            Tab(text: 'Orders (${_deletedOrders.length})'),
            Tab(text: 'Shops (${_deletedCustomers.length})'),
            Tab(text: 'Products (${_deletedProducts.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDeletedOrdersTab(),
                _buildDeletedCustomersTab(),
                _buildDeletedProductsTab(),
              ],
            ),
    );
  }
}
