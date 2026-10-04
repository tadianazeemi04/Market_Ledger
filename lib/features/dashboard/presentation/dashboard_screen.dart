import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/foldable_utils.dart';
import '../../../core/widgets/foldable_two_pane.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/status_chips.dart';
import '../../../core/widgets/workflow_guide_dialog.dart';
import '../../../core/utils/string_utils.dart';
import '../../customers/presentation/customer_form_screen.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../orders/domain/order_model.dart';
import '../../orders/presentation/create_order_screen.dart';
import '../../orders/presentation/order_detail_screen.dart';
import '../../orders/presentation/order_providers.dart';
import '../../settings/presentation/settings_provider.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final void Function(int) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _hasCheckedTour = false;
  bool _dismissedCoachMark = false;

  void _checkWorkflowTour(AppSettings settings) {
    if (_hasCheckedTour) return;
    _hasCheckedTour = true;
    if (settings.isOnboardingCompleted && !settings.isDemoAccount && !settings.hasSeenWorkflowTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          WorkflowGuideDialog.show(
            context,
            onSwitchToCatalogTab: () => widget.onNavigateToTab(3),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    _checkWorkflowTour(settings);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'lib/Logo/MarketLedgerLogo.png',
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.storefront_rounded,
                color: AppColors.primaryNavy,
                size: 32,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MarketLedger',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepNavy,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Wholesale Field Sales',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 24),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.emeraldGreen.withAlpha(50)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 13, color: AppColors.emeraldGreen),
                SizedBox(width: 4),
                Text(
                  'Offline-First',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(orderListProvider);
        },
        child: metricsAsync.when(
          loading: () {
            final leftPane = ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildGreetingCard(settings),
                const SizedBox(height: 16),
                const SkeletonList(count: 2),
              ],
            );
            final rightPane = ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: const [
                SkeletonList(count: 3),
              ],
            );
            final singlePane = ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildGreetingCard(settings),
                const SizedBox(height: 16),
                const SkeletonList(count: 3),
              ],
            );
            return FoldableTwoPane(
              startPane: leftPane,
              endPane: rightPane,
              singlePane: singlePane,
            );
          },
          error: (err, stack) => Center(
            child: Text('Error loading dashboard: $err'),
          ),
          data: (metrics) {
            final hasNoOrders = metrics.recentOrders.isEmpty;

            // Two-pane: Left screen (Overview & Summary metrics)
            final leftPaneContent = ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildGreetingCard(settings),
                const SizedBox(height: 16),
                _buildSummaryGrid(context, metrics, settings),
                const SizedBox(height: 16),
                _buildQuickActions(context, ref),
                const SizedBox(height: 16),
                _buildDuoOptimizationCard(context),
                const SizedBox(height: 100),
              ],
            );

            // Two-pane: Right screen (Active orders or getting started)
            final rightPaneContent = ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (hasNoOrders) ...[
                  _buildGettingStartedWorkflowCard(context, ref),
                  const SizedBox(height: 16),
                  if (!_dismissedCoachMark) ...[
                    _buildNewOrderCoachMark(),
                    const SizedBox(height: 16),
                  ],
                  _buildEmptyOrdersCard(),
                ] else ...[
                  Row(
                    children: [
                      const Text(
                        'Recent Orders',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => widget.onNavigateToTab(1),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                        label: const Text('View All', style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...metrics.recentOrders.map((order) => _buildOrderTile(context, order, settings, ref)),
                ],
                const SizedBox(height: 100),
              ],
            );

            // Single-pane (Folded outer display or standard mobile)
            final singlePaneContent = ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildGreetingCard(settings),
                const SizedBox(height: 16),
                _buildSummaryGrid(context, metrics, settings),
                const SizedBox(height: 16),
                _buildQuickActions(context, ref),
                const SizedBox(height: 20),
                if (hasNoOrders) ...[
                  _buildGettingStartedWorkflowCard(context, ref),
                  const SizedBox(height: 16),
                  if (!_dismissedCoachMark) ...[
                    _buildNewOrderCoachMark(),
                    const SizedBox(height: 16),
                  ],
                ],
                Row(
                  children: [
                    const Text(
                      'Recent Orders',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    if (!hasNoOrders) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => widget.onNavigateToTab(1),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                        label: const Text('View All', style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (hasNoOrders)
                  _buildEmptyOrdersCard()
                else
                  ...metrics.recentOrders.map((order) => _buildOrderTile(context, order, settings, ref)),
                const SizedBox(height: 100),
              ],
            );

            return FoldableTwoPane(
              startPane: leftPaneContent,
              endPane: rightPaneContent,
              singlePane: singlePaneContent,
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          ref.invalidate(dashboardProvider);
          ref.invalidate(orderListProvider);
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text(
          'New Order',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _formatGreetingName(AppSettings settings) {
    return StringUtils.formatGreetingName(settings);
  }

  Widget _buildGreetingCard(AppSettings settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.deepNavy, AppColors.primaryNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormatter.getGreeting()}, ${_formatGreetingName(settings)}!',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: AppColors.white,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateFormatter.formatFullGreetingDate(DateTime.now()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.white.withAlpha(230),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, DashboardMetrics metrics, AppSettings settings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final card1 = _buildMetricCard(
          title: "Today's Orders",
          value: '${metrics.todayOrdersCount}',
          subtitle: 'Active bookings',
          icon: Icons.shopping_bag_outlined,
          iconColor: AppColors.primaryNavy,
          accentColor: AppColors.primaryNavy,
        );
        final card2 = _buildMetricCard(
          title: 'Order Value',
          value: CurrencyFormatter.format(metrics.todayOrderValue, currency: settings.currency),
          subtitle: 'Booked today',
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.primaryNavy,
          accentColor: AppColors.primaryNavy,
        );
        final card3 = _buildMetricCard(
          title: 'Advances Collected',
          value: CurrencyFormatter.format(metrics.advancesCollected, currency: settings.currency),
          subtitle: 'Cash & transfers today',
          icon: Icons.payments_outlined,
          iconColor: AppColors.emeraldGreen,
          accentColor: AppColors.emeraldGreen,
        );
        final card4 = _buildMetricCard(
          title: 'Pending Balance',
          value: CurrencyFormatter.format(metrics.pendingBalance, currency: settings.currency),
          subtitle: 'Outstanding dues',
          icon: Icons.pending_actions_rounded,
          iconColor: AppColors.amberAccent,
          accentColor: AppColors.amberAccent,
        );

        if (constraints.maxWidth >= 640) {
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 12),
              Expanded(child: card2),
              const SizedBox(width: 12),
              Expanded(child: card3),
              const SizedBox(width: 12),
              Expanded(child: card4),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: card1),
                const SizedBox(width: 12),
                Expanded(child: card2),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: card3),
                const SizedBox(width: 12),
                Expanded(child: card4),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: accentColor == AppColors.primaryNavy ? AppColors.deepNavy : accentColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGettingStartedWorkflowCard(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: AppColors.primaryNavy, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Getting Started: Sales Workflow',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
                    ),
                    Text(
                      'Follow these 3 steps to take your first order',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => WorkflowGuideDialog.show(
                  context,
                  onSwitchToCatalogTab: () => widget.onNavigateToTab(3),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View Guide', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Step 1
          _buildWorkflowRow(
            number: '1',
            icon: Icons.storefront_rounded,
            title: 'Add your first retail shop',
            description: 'Save shopkeeper name, phone, and market location',
            buttonLabel: 'Add Shop',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
              );
              ref.invalidate(customerListProvider);
              ref.invalidate(dashboardProvider);
            },
          ),
          const SizedBox(height: 10),

          // Step 2
          _buildWorkflowRow(
            number: '2',
            icon: Icons.inventory_2_rounded,
            title: 'Configure wholesale catalog',
            description: 'Setup products, units (Bags, Cartons, kg), and prices',
            buttonLabel: 'Open Catalog',
            onTap: () => widget.onNavigateToTab(3),
          ),
          const SizedBox(height: 10),

          // Step 3
          _buildWorkflowRow(
            number: '3',
            icon: Icons.add_shopping_cart_rounded,
            title: 'Book order & collect advance',
            description: 'Tap "New Order" at the bottom-right corner',
            buttonLabel: 'New Order',
            isPrimary: true,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
              );
              ref.invalidate(orderListProvider);
              ref.invalidate(dashboardProvider);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowRow({
    required String number,
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primaryNavy : AppColors.primaryNavy.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isPrimary ? Colors.white : AppColors.primaryNavy,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
              ),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: isPrimary ? AppColors.primaryNavy : AppColors.primaryNavy.withValues(alpha: 0.1),
            foregroundColor: isPrimary ? Colors.white : AppColors.primaryNavy,
          ),
          child: Text(buttonLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildNewOrderCoachMark() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.amberAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.touch_app_rounded, color: AppColors.amberAccent, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '👉 Tap "New Order" in the bottom-right corner to start your first wholesale order!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _dismissedCoachMark = true),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
              );
              ref.invalidate(dashboardProvider);
              ref.invalidate(orderListProvider);
            },
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
            label: const Text('New Order'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
              );
              ref.invalidate(dashboardProvider);
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Shop', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: () => widget.onNavigateToTab(3), // Products tab
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const Text('Catalog', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTile(BuildContext context, OrderModel order, AppSettings settings, WidgetRef ref) {
    final customer = order.customer;
    final shopName = customer?.shopName ?? 'Unknown Shop';
    final ownerName = customer?.ownerName ?? 'Customer';

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
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: order.id),
            ),
          );
          ref.invalidate(dashboardProvider);
          ref.invalidate(orderListProvider);
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
                    DateFormatter.formatRelativeOrDate(order.orderDate),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                shopName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                ownerName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CurrencyFormatter.format(order.grandTotal, currency: settings.currency),
                        style: const TextStyle(
                          fontSize: 15,
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

  Widget _buildEmptyOrdersCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.secondaryText),
          SizedBox(height: 10),
          Text(
            'No Orders Recorded Yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
          ),
          SizedBox(height: 6),
          Text(
            'Your wholesale bookings and payment balances will show here. Use the New Order button below to record your first booking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildDuoOptimizationCard(BuildContext context) {
    final hasHinge = FoldableUtils.getVerticalHinge(context) != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNavy.withAlpha(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasHinge ? Icons.devices_fold_rounded : Icons.splitscreen_rounded,
              size: 20,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasHinge ? 'iPhone Duo Dual-Screen Active' : 'Two-Pane Productivity Active',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasHinge
                      ? 'Left screen: Overview & metrics. Right screen: Active orders stream.'
                      : 'Overview on the left, active operations and orders on the right.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
