import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_chips.dart';
import '../../customers/domain/customer_model.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../../receipt/presentation/receipt_dialog.dart';
import '../../receipt/services/receipt_service.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/order_model.dart';
import 'create_order_screen.dart';
import 'order_providers.dart';
import 'record_payment_dialog.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  final bool showBackButton;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    return orderAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: showBackButton,
          title: const Text('Order Details'),
        ),
        body: Center(child: Text('Error loading order: $err')),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: showBackButton,
              title: const Text('Order Details'),
            ),
            body: const Center(child: Text('Order not found.')),
          );
        }

        final customer = order.customer;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: showBackButton,
            title: Text(order.orderNumber),
            actions: [
              IconButton(
                tooltip: 'Share Receipt',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => ReceiptDialog.show(context, order),
              ),
              IconButton(
                tooltip: 'Edit Order',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateOrderScreen(orderToEdit: order),
                    ),
                  );
                  ref.invalidate(orderDetailProvider(orderId));
                  ref.invalidate(orderListProvider);
                  ref.invalidate(dashboardProvider);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'copy') {
                    ReceiptService.copyToClipboard(context, order, settings);
                  } else if (value == 'delete') {
                    final confirmed = await ConfirmDialog.show(
                      context,
                      title: 'Delete Order?',
                      message: 'Are you sure you want to delete order ${order.orderNumber}?',
                      confirmLabel: 'Delete',
                      confirmColor: AppColors.errorRed,
                      icon: Icons.delete_forever_rounded,
                    );
                    if (confirmed && context.mounted) {
                      final navigator = Navigator.of(context);
                      await ref.read(orderRepositoryProvider).deleteOrder(order.id);
                      ref.invalidate(orderListProvider);
                      ref.invalidate(dashboardProvider);
                      navigator.pop();
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Copy Receipt Summary'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppColors.errorRed, size: 18),
                        SizedBox(width: 8),
                        Text('Delete Order', style: TextStyle(color: AppColors.errorRed)),
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
              // Order Summary Header Card
              _buildHeaderCard(context, order, ref),
              const SizedBox(height: 16),

              // Customer Details Card
              _buildCustomerCard(context, customer),
              const SizedBox(height: 16),

              // Itemized Products Card
              _buildProductsCard(order, settings),
              const SizedBox(height: 16),

              // Financial Breakdown Card
              _buildFinancialCard(order, settings),
              const SizedBox(height: 16),

              // Payments History Section
              _buildPaymentsSection(context, order, settings, ref),
              const SizedBox(height: 16),

              // Notes Card
              if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                _buildNotesCard(order.notes!),
                const SizedBox(height: 16),
              ],

              // Timestamps Card
              _buildTimestampsCard(order),
              const SizedBox(height: 90), // Spacing for bottom action bar
            ],
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.cardSurface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (order.balanceAmount > 0) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => RecordPaymentDialog.show(context, order),
                      icon: const Icon(Icons.add_card_rounded, size: 18),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGreen),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (order.status != OrderStatus.delivered) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await ConfirmDialog.show(
                          context,
                          title: 'Mark as Delivered?',
                          message: 'Mark order ${order.orderNumber} as delivered to customer?',
                          confirmLabel: 'Mark Delivered',
                          confirmColor: AppColors.primaryNavy,
                          icon: Icons.task_alt_rounded,
                        );
                        if (confirmed && context.mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          await ref.read(orderRepositoryProvider).markDelivered(order.id);
                          ref.invalidate(orderDetailProvider(orderId));
                          ref.invalidate(orderListProvider);
                          ref.invalidate(dashboardProvider);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Order marked as delivered!'),
                              backgroundColor: AppColors.emeraldGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Mark Delivered'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ReceiptDialog.show(context, order),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('View & Share Receipt'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context, OrderModel order, WidgetRef ref) {
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
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORDER NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondaryText, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OrderStatusChip(status: order.status),
                    PaymentStatusChip(status: order.paymentStatus),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.secondaryText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Booked: ${DateFormatter.formatDateTime(order.orderDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (order.deliveryDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.secondaryText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Delivery: ${DateFormatter.formatDate(order.deliveryDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Customer? customer) {
    if (customer == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text('Customer information unavailable'),
      );
    }

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
            children: [
              const Icon(Icons.storefront_rounded, size: 20, color: AppColors.primaryNavy),
              const SizedBox(width: 8),
              const Text(
                'Customer / Retail Shop',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            customer.shopName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Owner: ${customer.ownerName}',
            style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
          if (customer.phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppColors.primaryNavy),
                const SizedBox(width: 6),
                Text(
                  customer.phone,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
                ),
              ],
            ),
          ],
          if (customer.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.secondaryText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    customer.address,
                    style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  ),
                ),
              ],
            ),
          ],
          if (customer.hasCoordinates) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.emeraldGreen),
                const SizedBox(width: 6),
                Text(
                  'GPS: ${customer.latitude!.toStringAsFixed(4)}, ${customer.longitude!.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.emeraldGreen, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsCard(OrderModel order, AppSettings settings) {
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
          Text(
            'Itemized Products (${order.items.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.items.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = order.items[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.inputBackground,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondaryText),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productNameSnapshot,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice, currency: settings.currency)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                        if (item.discountAmount > 0)
                          Text(
                            'Item discount: -${CurrencyFormatter.format(item.discountAmount, currency: settings.currency)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.errorRed, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(item.lineTotal, currency: settings.currency),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.deepNavy),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(OrderModel order, AppSettings settings) {
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
          const Text(
            'Financial Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 12),
          _buildRow('Subtotal', CurrencyFormatter.format(order.subtotal, currency: settings.currency)),
          if (order.discountAmount > 0)
            _buildRow('Order Discount', '-${CurrencyFormatter.format(order.discountAmount, currency: settings.currency)}', isDeduction: true),
          if (order.deliveryCharge > 0)
            _buildRow('Delivery Charges', '+${CurrencyFormatter.format(order.deliveryCharge, currency: settings.currency)}'),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
              ),
              const SizedBox(width: 8),
              Text(
                CurrencyFormatter.format(order.grandTotal, currency: settings.currency),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRow('Advance / Paid Amount', CurrencyFormatter.format(order.advanceAmount, currency: settings.currency), isSuccess: true),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Outstanding Balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(
                CurrencyFormatter.format(order.balanceAmount, currency: settings.currency),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: order.balanceAmount > 0 ? AppColors.amberAccent : AppColors.emeraldGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String title, String value, {bool isDeduction = false, bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDeduction
                  ? AppColors.errorRed
                  : isSuccess
                      ? AppColors.emeraldGreen
                      : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(BuildContext context, OrderModel order, AppSettings settings, WidgetRef ref) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Records (${order.payments.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              if (order.balanceAmount > 0)
                TextButton.icon(
                  onPressed: () => RecordPaymentDialog.show(context, order),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Record'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (order.payments.isEmpty)
            const Text(
              'No payments recorded yet for this order.',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.payments.length,
              separatorBuilder: (_, _) => const Divider(height: 14),
              itemBuilder: (context, index) {
                final p = order.payments[index];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.payment_rounded, size: 16, color: AppColors.emeraldGreen),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                p.method.label,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              if (p.referenceNumber != null && p.referenceNumber!.isNotEmpty)
                                Text(
                                  '#${p.referenceNumber}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                ),
                            ],
                          ),
                          Text(
                            DateFormatter.formatDateTime(p.paidAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                          ),
                          if (p.note != null && p.note!.isNotEmpty)
                            Text(
                              p.note!,
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(p.amount, currency: settings.currency),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldGreen,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amberAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amberAccent.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, size: 16, color: AppColors.amberAccent),
              SizedBox(width: 6),
              Text(
                'Order Notes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(notes, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildTimestampsCard(OrderModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Created: ${DateFormatter.formatDate(order.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
            ),
            Text(
              'Updated: ${DateFormatter.formatDate(order.updatedAt)}',
              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
