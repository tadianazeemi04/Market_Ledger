import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/foldable_two_pane.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/customer_model.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';
import 'customer_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCustomerId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    Widget buildCustomerListPane({required bool isTwoPaneMode}) {
      return Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search shops, owners, market areas...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(customerSearchQueryProvider.notifier).clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) {
                ref.read(customerSearchQueryProvider.notifier).setQuery(val);
              },
            ),
          ),

          // Customer List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(customerListProvider);
              },
              child: customersAsync.when(
                loading: () => const SkeletonList(count: 5),
                error: (err, _) => Center(child: Text('Error loading customers: $err')),
                data: (customers) {
                  if (customers.isEmpty) {
                    final isSearching = _searchController.text.isNotEmpty;
                    return EmptyStateWidget(
                      icon: isSearching ? Icons.search_off_rounded : Icons.store_mall_directory_outlined,
                      title: isSearching ? 'No Shops Found' : 'No Shops Registered',
                      message: isSearching
                          ? 'No matching retail shops found for "${_searchController.text}".'
                          : 'Register wholesale retail shops and market vendors to begin booking orders.',
                      actionLabel: isSearching ? null : 'Register Shop',
                      onAction: isSearching
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
                              );
                              ref.invalidate(customerListProvider);
                            },
                    );
                  }

                  // Auto select first customer if in two-pane mode
                  if (isTwoPaneMode) {
                    if (_selectedCustomerId == null || !customers.any((c) => c.id == _selectedCustomerId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedCustomerId = customers.first.id;
                          });
                        }
                      });
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 4),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return _buildCustomerItem(
                        context,
                        customer,
                        settings,
                        isSelected: isTwoPaneMode && customer.id == _selectedCustomerId,
                        onTapOverride: isTwoPaneMode
                            ? () {
                                setState(() {
                                  _selectedCustomerId = customer.id;
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

    final rightPane = _selectedCustomerId != null
        ? CustomerDetailScreen(
            key: ValueKey(_selectedCustomerId),
            customerId: _selectedCustomerId!,
            showBackButton: false,
          )
        : _buildEmptySelectionPlaceholder();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers & Shops'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(customerListProvider),
          ),
        ],
      ),
      body: FoldableTwoPane(
        startPane: buildCustomerListPane(isTwoPaneMode: true),
        endPane: rightPane,
        singlePane: buildCustomerListPane(isTwoPaneMode: false),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
          );
          ref.invalidate(customerListProvider);
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Shop', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptySelectionPlaceholder() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
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
                child: const Icon(Icons.storefront_rounded, size: 40, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a Customer Shop',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select any shop from the directory on the left to inspect market area details, contact information, and order ledger history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerItem(
    BuildContext context,
    Customer customer,
    AppSettings settings, {
    bool isSelected = false,
    VoidCallback? onTapOverride,
  }) {
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
              builder: (_) => CustomerDetailScreen(customerId: customer.id),
            ),
          );
          ref.invalidate(customerListProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primaryNavy, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.shopName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.secondaryText),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customer.ownerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (customer.marketArea.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Phone
                  if (customer.phone.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: customer.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${customer.phone}'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.primaryNavy),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'No phone',
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),

                  // Last order / spend info
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: AppColors.secondaryText),
                      const SizedBox(width: 4),
                      Text(
                        customer.lastOrderDate != null
                            ? 'Last: ${DateFormatter.formatDate(customer.lastOrderDate)}'
                            : 'No orders',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
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
