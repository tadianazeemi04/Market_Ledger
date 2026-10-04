import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/product_repository.dart';
import '../domain/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

class ProductSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

final productSearchQueryProvider =
    NotifierProvider<ProductSearchNotifier, String>(ProductSearchNotifier.new);

class ProductActiveOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final productActiveOnlyProvider =
    NotifierProvider<ProductActiveOnlyNotifier, bool>(ProductActiveOnlyNotifier.new);

final productListProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final query = ref.watch(productSearchQueryProvider);
  final activeOnly = ref.watch(productActiveOnlyProvider);
  return await repo.getProducts(searchQuery: query, activeOnly: activeOnly);
});
