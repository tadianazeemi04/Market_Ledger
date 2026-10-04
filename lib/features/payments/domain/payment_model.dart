import '../../../core/constants/enums.dart';

class Payment {
  final String id;
  final String orderId;
  final double amount;
  final PaymentMethod method;
  final String? referenceNumber;
  final String? note;
  final DateTime paidAt;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.method,
    this.referenceNumber,
    this.note,
    required this.paidAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'amount': amount,
      'method': method.name,
      'referenceNumber': referenceNumber,
      'note': note,
      'paidAt': paidAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      amount: (map['amount'] as num).toDouble(),
      method: PaymentMethod.fromString(map['method'] as String?),
      referenceNumber: map['referenceNumber'] as String?,
      note: map['note'] as String?,
      paidAt: DateTime.tryParse(map['paidAt'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Payment copyWith({
    String? id,
    String? orderId,
    double? amount,
    PaymentMethod? method,
    String? referenceNumber,
    String? note,
    DateTime? paidAt,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      note: note ?? this.note,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
