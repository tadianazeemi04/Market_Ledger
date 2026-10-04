import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/payment_repository.dart';
import '../domain/payment_model.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final orderPaymentsProvider = FutureProvider.family<List<Payment>, String>((ref, orderId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return await repo.getPaymentsForOrder(orderId);
});
