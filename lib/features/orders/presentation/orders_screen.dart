import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/foldable_two_pane.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/status_chips.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/order_model.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';
import 'order_providers.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedOrderId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DisplayFeatureSubScreen(
          anchorPoint: Offset.zero,
          child: Consumer(
            builder: (context, ref, _) {
              final filter = ref.watch(orderFilterProvider);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(orderFilterProvider.notifier).state = const OrderFilterState();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date Filters
                  const Text('Date Period', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: DateFilterOption.values.map((opt) {
                      final isSelected = filter.dateFilter == opt;
                      return ChoiceChip(
                        label: Text(opt.label),
                        selected: isSelected,
                        selectedColor: AppColors.primaryNavy.withAlpha(25),
                        onSelected: (val) {
                          ref.read(orderFilterProvider.notifier).update(
                                (s) => s.copyWith(dateFilter: opt),
                              );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Order Status Filters
                  const Text('Order Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: filter.status == null,
                        onSelected: (_) {
                          ref.read(orderFilterProvider.notifier).update(
                                (s) => s.copyWith(status: () => null),
                              );
                        },
                      ),
                      ...OrderStatus.values.map((st) {
                        return ChoiceChip(
                          label: Text(st.label),
                          selected: filter.status == st,
                          selectedColor: AppColors.primaryNavy.withAlpha(25),
                          onSelected: (val) {
                            ref.read(orderFilterProvider.notifier).update(
                                  (s) => s.copyWith(status: () => val ? st : null),
                                );
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Payment Status Filters
                  const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: filter.paymentStatus == null,
                        onSelected: (_) {
                          ref.read(orderFilterProvider.notifier).update(
                                (s) => s.copyWith(paymentStatus: () => null),
                              );
                        },
                      ),
                      ...PaymentStatus.values.map((ps) {
                        return ChoiceChip(
                          label: Text(ps.label),
                          selected: filter.paymentStatus == ps,
                          selectedColor: AppColors.primaryNavy.withAlpha(25),
                          onSelected: (val) {
                            ref.read(orderFilterProvider.notifier).update(
                                  (s) => s.copyWith(paymentStatus: () => val ? ps : null),
                                );
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderListProvider);
    final filter = ref.watch(orderFilterProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    Widget buildOrderListPane({required bool isTwoPaneMode}) {
      return Column(
        children: [
          // Search & Quick Status Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search order #, shop, owner, area...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(orderFilterProvider.notifier).update(
                                (s) => s.copyWith(searchQuery: ''),
                              );
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) {
                ref.read(orderFilterProvider.notifier).update(
                      (s) => s.copyWith(searchQuery: val),
                    );
              },
            ),
          ),

          // Horizontal Status Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 14),
                  label: Text(filter.dateFilter.label),
                  onPressed: _openFilterSheet,
                  backgroundColor: AppColors.cardSurface,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All Status'),
                  selected: filter.status == null,
                  onSelected: (_) {
                    ref.read(orderFilterProvider.notifier).update((s) => s.copyWith(status: () => null));
                  },
                ),
                const SizedBox(width: 6),
                ...OrderStatus.values.map((st) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(st.label),
                      selected: filter.status == st,
                      selectedColor: AppColors.primaryNavy.withAlpha(25),
                      onSelected: (val) {
                        ref.read(orderFilterProvider.notifier).update(
                              (s) => s.copyWith(status: () => val ? st : null),
                            );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Order Cards List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(orderListProvider),
              child: ordersAsync.when(
                loading: () => const SkeletonList(count: 4),
                error: (err, _) => Center(child: Text('Error loading orders: $err')),
                data: (orders) {
                  if (orders.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Orders Found',
                      message: filter.hasActiveFilters
                          ? 'No orders match your filter criteria. Try clearing search or filters.'
                          : 'You haven\'t recorded any wholesale orders yet.',
                      actionLabel: filter.hasActiveFilters ? 'Clear Filters' : 'Create Order',
                      onAction: filter.hasActiveFilters
                          ? () {
                              _searchController.clear();
                              ref.read(orderFilterProvider.notifier).state = const OrderFilterState();
                            }
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                              );
                              ref.invalidate(orderListProvider);
                            },
                    );
                  }

                  // Auto select first order if in two-pane mode and none selected or deleted
                  if (isTwoPaneMode) {
                    if (_selectedOrderId == null || !orders.any((o) => o.id == _selectedOrderId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedOrderId = orders.first.id;
                          });
                        }
                      });
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 4),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCard(
                        context,
                        order,
                        settings,
                        isSelected: isTwoPaneMode && order.id == _selectedOrderId,
                        onTapOverride: isTwoPaneMode
                            ? () {
                                setState(() {
                                  _selectedOrderId = order.id;
                                });
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    final rightPane = _selectedOrderId != null
        ? OrderDetailScreen(
            key: ValueKey(_selectedOrderId),
            orderId: _selectedOrderId!,
            showBackButton: false,
          )
        : _buildEmptySelectionPlaceholder();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders & Bookings'),
        actions: [
          IconButton(
            tooltip: 'Filter Orders',
            icon: Badge(
              isLabelVisible: filter.hasActiveFilters,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: _openFilterSheet,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(orderListProvider),
          ),
        ],
      ),
      body: FoldableTwoPane(
        startPane: buildOrderListPane(isTwoPaneMode: true),
        endPane: rightPane,
        singlePane: buildOrderListPane(isTwoPaneMode: false),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          ref.invalidate(orderListProvider);
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('New Order', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptySelectionPlaceholder() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.touch_app_rounded, size: 40, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select an Order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select any order from the left pane to view full line items, wholesale totals, and payment history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    AppSettings settings, {
    bool isSelected = false,
    VoidCallback? onTapOverride,
  }) {
    final customer = order.customer;
    final shopName = customer?.shopName ?? 'Unknown Shop';
    final ownerName = customer?.ownerName ?? 'Customer';
    final area = customer?.marketArea ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryNavy.withAlpha(12) : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primaryNavy : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (onTapOverride != null) {
            onTapOverride();
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: order.id),
            ),
          );
          ref.invalidate(orderListProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line: order number & date
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
              const SizedBox(height: 6),

              // Shop & Owner
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        Text(
                          '$ownerName${area.isNotEmpty ? ' • $area' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(order.grandTotal, currency: settings.currency),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      if (order.balanceAmount > 0)
                        Text(
                          'Bal: ${CurrencyFormatter.format(order.balanceAmount, currency: settings.currency)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amberAccent,
                          ),
                        )
                      else
                        const Text(
                          'Paid in Full',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Status Chips & Advance info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Adv: ${CurrencyFormatter.format(order.advanceAmount, currency: settings.currency)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                      ),
                    ],
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
