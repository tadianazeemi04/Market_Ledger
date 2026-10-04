import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chips.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/presentation/create_order_screen.dart';
import '../../orders/presentation/order_detail_screen.dart';
import '../../orders/presentation/order_providers.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/customer_model.dart';
import 'customer_form_screen.dart';
import 'customer_providers.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;
  final bool showBackButton;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final ordersAsync = ref.watch(customerOrdersProvider(customerId));
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    return customerAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: showBackButton,
          title: const Text('Customer Details'),
        ),
        body: Center(child: Text('Error loading customer: $err')),
      ),
      data: (customer) {
        if (customer == null) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: showBackButton,
              title: const Text('Customer Details'),
            ),
            body: const Center(child: Text('Customer not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: showBackButton,
            title: Text(customer.shopName),
            actions: [
              IconButton(
                tooltip: 'Edit Shop',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerFormScreen(customerToEdit: customer),
                    ),
                  );
                  ref.invalidate(customerDetailProvider(customerId));
                  ref.invalidate(customerListProvider);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirmed = await ConfirmDialog.show(
                      context,
                      title: 'Delete Customer?',
                      message: 'Are you sure you want to delete ${customer.shopName}? All past orders for this customer will also be deleted.',
                      confirmLabel: 'Delete',
                      confirmColor: AppColors.errorRed,
                      icon: Icons.delete_forever_rounded,
                    );
                    if (confirmed && context.mounted) {
                      final navigator = Navigator.of(context);
                      await ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
                      ref.invalidate(customerListProvider);
                      ref.invalidate(orderListProvider);
                      navigator.pop();
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppColors.errorRed, size: 20),
                        SizedBox(width: 8),
                        Text('Delete Customer', style: TextStyle(color: AppColors.errorRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main Profile Card
              _buildProfileCard(context, customer),
              const SizedBox(height: 16),

              // Summary Stats (Orders, Total Spent, Last Order)
              _buildStatsRow(customer, settings),
              const SizedBox(height: 16),

              // Notes Card if present
              if (customer.notes != null && customer.notes!.trim().isNotEmpty) ...[
                _buildNotesCard(customer),
                const SizedBox(height: 16),
              ],

              // Order History Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order History',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  Text(
                    '${customer.totalOrders} total',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Orders List
              ordersAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                )),
                error: (err, _) => Center(child: Text('Error loading orders: $err')),
                data: (orders) {
                  if (orders.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Orders Yet',
                        message: 'This shop hasn\'t placed any orders yet.',
                      ),
                    );
                  }
                  return Column(
                    children: orders.map((order) => _buildOrderCard(context, order, settings, ref)).toList(),
                  );
                },
              ),

              const SizedBox(height: 80),
            ],
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.cardSurface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateOrderScreen(preselectedCustomer: customer),
                  ),
                );
                ref.invalidate(customerDetailProvider(customerId));
                ref.invalidate(customerOrdersProvider(customerId));
                ref.invalidate(customerListProvider);
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text('New Order for ${customer.shopName}'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, Customer customer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primaryNavy, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.shopName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          customer.ownerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (customer.marketArea.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    customer.marketArea,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),

          // Phone
          if (customer.phone.isNotEmpty) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Clipboard.setData(ClipboardData(text: customer.phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied phone number: ${customer.phone}'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 18, color: AppColors.primaryNavy),
                    const SizedBox(width: 10),
                    Text(
                      customer.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Address
          if (customer.address.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.secondaryText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    customer.address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // GPS coordinates
          Row(
            children: [
              Icon(
                customer.hasCoordinates ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                size: 16,
                color: customer.hasCoordinates ? AppColors.emeraldGreen : AppColors.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                customer.hasCoordinates
                    ? 'GPS: ${customer.latitude!.toStringAsFixed(4)}, ${customer.longitude!.toStringAsFixed(4)}'
                    : 'GPS coordinates not captured',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: customer.hasCoordinates ? FontWeight.w600 : FontWeight.w400,
                  color: customer.hasCoordinates ? AppColors.emeraldGreen : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Customer customer, AppSettings settings) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Spent',
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(customer.totalSpent, currency: settings.currency),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Order',
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    DateFormatter.formatDate(customer.lastOrderDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(Customer customer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amberAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, size: 16, color: AppColors.amberAccent),
              SizedBox(width: 6),
              Text(
                'Notes & Terms',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            customer.notes!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primaryText,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order, AppSettings settings, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
          );
          ref.invalidate(customerOrdersProvider(customerId));
          ref.invalidate(customerDetailProvider(customerId));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  Text(
                    DateFormatter.formatDate(order.orderDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyFormatter.format(order.grandTotal, currency: settings.currency),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  Row(
                    children: [
                      PaymentStatusChip(status: order.paymentStatus, isCompact: true),
                      const SizedBox(width: 6),
                      OrderStatusChip(status: order.status, isCompact: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
