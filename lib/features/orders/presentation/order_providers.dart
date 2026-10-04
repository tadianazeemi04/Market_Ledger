import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../data/order_repository.dart';
import '../domain/order_model.dart';

enum DateFilterOption {
  all('All Time'),
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month');

  final String label;
  const DateFilterOption(this.label);
}

class OrderFilterState {
  final String searchQuery;
  final OrderStatus? status;
  final PaymentStatus? paymentStatus;
  final String? marketArea;
  final DateFilterOption dateFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const OrderFilterState({
    this.searchQuery = '',
    this.status,
    this.paymentStatus,
    this.marketArea,
    this.dateFilter = DateFilterOption.all,
    this.customStartDate,
    this.customEndDate,
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      status != null ||
      paymentStatus != null ||
      (marketArea != null && marketArea!.isNotEmpty) ||
      dateFilter != DateFilterOption.all ||
      customStartDate != null;

  OrderFilterState copyWith({
    String? searchQuery,
    OrderStatus? Function()? status,
    PaymentStatus? Function()? paymentStatus,
    String? Function()? marketArea,
    DateFilterOption? dateFilter,
    DateTime? Function()? customStartDate,
    DateTime? Function()? customEndDate,
  }) {
    return OrderFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      status: status != null ? status() : this.status,
      paymentStatus: paymentStatus != null ? paymentStatus() : this.paymentStatus,
      marketArea: marketArea != null ? marketArea() : this.marketArea,
      dateFilter: dateFilter ?? this.dateFilter,
      customStartDate: customStartDate != null ? customStartDate() : this.customStartDate,
      customEndDate: customEndDate != null ? customEndDate() : this.customEndDate,
    );
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

class OrderFilterNotifier extends Notifier<OrderFilterState> {
  @override
  OrderFilterState build() => const OrderFilterState();

  @override
  set state(OrderFilterState value) => super.state = value;

  void update(OrderFilterState Function(OrderFilterState) updater) {
    state = updater(state);
  }

  void reset() {
    state = const OrderFilterState();
  }
}

final orderFilterProvider =
    NotifierProvider<OrderFilterNotifier, OrderFilterState>(OrderFilterNotifier.new);

final orderListProvider = FutureProvider<List<OrderModel>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final filter = ref.watch(orderFilterProvider);

  DateTime? startDate;
  DateTime? endDate;

  final now = DateTime.now();
  switch (filter.dateFilter) {
    case DateFilterOption.today:
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DateFilterOption.thisWeek:
      final monday = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateTime(monday.year, monday.month, monday.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DateFilterOption.thisMonth:
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DateFilterOption.all:
      startDate = filter.customStartDate;
      endDate = filter.customEndDate;
      break;
  }

  return await repo.getOrders(
    query: filter.searchQuery,
    status: filter.status,
    paymentStatus: filter.paymentStatus,
    marketArea: filter.marketArea,
    startDate: startDate,
    endDate: endDate,
  );
});

final orderDetailProvider = FutureProvider.family<OrderModel?, String>((ref, orderId) async {
  final repo = ref.watch(orderRepositoryProvider);
  return await repo.getOrderById(orderId);
});
