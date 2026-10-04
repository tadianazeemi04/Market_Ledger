import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_repository.dart';
import '../domain/customer_model.dart';
import '../../orders/domain/order_model.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

class CustomerSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

final customerSearchQueryProvider =
    NotifierProvider<CustomerSearchNotifier, String>(CustomerSearchNotifier.new);

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  final query = ref.watch(customerSearchQueryProvider);
  return await repo.getCustomers(searchQuery: query);
});

final customerDetailProvider = FutureProvider.family<Customer?, String>((ref, id) async {
  final repo = ref.watch(customerRepositoryProvider);
  return await repo.getCustomerById(id);
});

final customerOrdersProvider = FutureProvider.family<List<OrderModel>, String>((ref, customerId) async {
  final repo = ref.watch(customerRepositoryProvider);
  return await repo.getCustomerOrders(customerId);
});
