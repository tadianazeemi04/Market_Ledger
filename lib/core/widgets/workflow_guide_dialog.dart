import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../features/customers/presentation/customer_form_screen.dart';
import '../../features/customers/presentation/customer_providers.dart';
import '../../features/dashboard/presentation/dashboard_provider.dart';
import '../../features/orders/presentation/create_order_screen.dart';
import '../../features/orders/presentation/order_providers.dart';
import '../../features/settings/presentation/settings_provider.dart';

class WorkflowGuideDialog extends ConsumerWidget {
  final VoidCallback? onSwitchToCatalogTab;

  const WorkflowGuideDialog({
    super.key,
    this.onSwitchToCatalogTab,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSwitchToCatalogTab}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DisplayFeatureSubScreen(
        anchorPoint: Offset.zero,
        child: WorkflowGuideDialog(onSwitchToCatalogTab: onSwitchToCatalogTab),
      ),
    );
  }

  Future<void> _markTourCompleted(WidgetRef ref) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.markWorkflowTourSeen();
      ref.invalidate(settingsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.cardSurface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.primaryNavy,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How MarketLedger Works',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Quick 3-step field sales workflow',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.secondaryText),
                    onPressed: () {
                      _markTourCompleted(ref);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Workflow Step 1: Add Retail Shops
              _buildStepCard(
                stepNumber: '1',
                stepColor: AppColors.primaryNavy,
                icon: Icons.storefront_rounded,
                title: 'Register Retail Shops',
                description:
                    'Record shop name, owner contact, and market area. In field visits, this keeps each shop\'s ledger and order history organized.',
                actionLabel: 'Add First Shop',
                onAction: () async {
                  _markTourCompleted(ref);
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
                  );
                  ref.invalidate(customerListProvider);
                  ref.invalidate(dashboardProvider);
                },
              ),
              const SizedBox(height: 12),

              // Workflow Step 2: Configure Products
              _buildStepCard(
                stepNumber: '2',
                stepColor: AppColors.amberAccent,
                icon: Icons.inventory_2_rounded,
                title: 'Add Wholesale Products',
                description:
                    'List your wholesale items, unit types (Bags, Cartons, Tins, kg), and default selling prices for fast order booking.',
                actionLabel: onSwitchToCatalogTab != null ? 'Open Catalog' : null,
                onAction: onSwitchToCatalogTab != null
                    ? () {
                        _markTourCompleted(ref);
                        Navigator.of(context).pop();
                        onSwitchToCatalogTab!();
                      }
                    : null,
              ),
              const SizedBox(height: 12),

              // Workflow Step 3: Book Orders & Collect Advances
              _buildStepCard(
                stepNumber: '3',
                stepColor: AppColors.emeraldGreen,
                icon: Icons.add_shopping_cart_rounded,
                title: 'Book Orders & Collect Advances',
                description:
                    'Tap the "New Order" button in the bottom-right corner anytime to select a shop, add products, record cash advances, and generate receipts.',
                actionLabel: 'Create Order Now',
                onAction: () async {
                  _markTourCompleted(ref);
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                  );
                  ref.invalidate(orderListProvider);
                  ref.invalidate(dashboardProvider);
                },
              ),
              const SizedBox(height: 18),

              // Bottom Info Box: Offline-First & Invoices
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.offline_bolt_rounded, size: 20, color: AppColors.emeraldGreen),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '100% Offline-First: All ledgers, shops, and orders are stored securely on your device and work without internet.',
                        style: TextStyle(fontSize: 12, color: AppColors.primaryText, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary Dismiss Button
              ElevatedButton(
                onPressed: () {
                  _markTourCompleted(ref);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Got It! Let\'s Start Selling',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required Color stepColor,
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: stepColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: stepColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: stepColor,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: stepColor.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
