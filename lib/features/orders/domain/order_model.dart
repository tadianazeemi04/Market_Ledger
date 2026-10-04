import '../../../core/constants/enums.dart';
import '../../customers/domain/customer_model.dart';
import 'order_item_model.dart';
import '../../payments/domain/payment_model.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final OrderStatus status;
  final double subtotal;
  final double discountAmount;
  final double deliveryCharge;
  final double grandTotal;
  final double advanceAmount;
  final double balanceAmount;
  final PaymentStatus paymentStatus;
  final String? notes;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined relations (optional)
  final Customer? customer;
  final List<OrderItem> items;
  final List<Payment> payments;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.orderDate,
    this.deliveryDate,
    required this.status,
    required this.subtotal,
    this.discountAmount = 0.0,
    this.deliveryCharge = 0.0,
    required this.grandTotal,
    this.advanceAmount = 0.0,
    required this.balanceAmount,
    required this.paymentStatus,
    this.notes,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.items = const [],
    this.payments = const [],
  });

  /// Recalculates financial totals and returns updated copy.
  static OrderFinancials calculateFinancials({
    required List<OrderItem> items,
    double overallDiscount = 0.0,
    double deliveryCharge = 0.0,
    double advancePaid = 0.0,
  }) {
    double subtotal = 0.0;
    for (final item in items) {
      subtotal += item.lineTotal;
    }

    final double discount = overallDiscount.clamp(0.0, subtotal);
    final double delivery = deliveryCharge.clamp(0.0, double.infinity);
    final double grandTotal = (subtotal - discount + delivery).clamp(0.0, double.infinity);

    final double advance = advancePaid.clamp(0.0, double.infinity);
    final double balance = (grandTotal - advance).clamp(0.0, double.infinity);

    final PaymentStatus paymentStatus = PaymentStatus.calculate(grandTotal, advance);

    return OrderFinancials(
      subtotal: subtotal,
      discountAmount: discount,
      deliveryCharge: delivery,
      grandTotal: grandTotal,
      advanceAmount: advance,
      balanceAmount: balance,
      paymentStatus: paymentStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'orderDate': orderDate.toIso8601String(),
      'deliveryDate': deliveryDate?.toIso8601String(),
      'status': status.name,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'deliveryCharge': deliveryCharge,
      'grandTotal': grandTotal,
      'advanceAmount': advanceAmount,
      'balanceAmount': balanceAmount,
      'paymentStatus': paymentStatus.name,
      'notes': notes,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OrderModel.fromMap(
    Map<String, dynamic> map, {
    Customer? customer,
    List<OrderItem> items = const [],
    List<Payment> payments = const [],
  }) {
    return OrderModel(
      id: map['id'] as String,
      orderNumber: map['orderNumber'] as String,
      customerId: map['customerId'] as String,
      orderDate: DateTime.tryParse(map['orderDate'] as String? ?? '') ?? DateTime.now(),
      deliveryDate: map['deliveryDate'] != null ? DateTime.tryParse(map['deliveryDate'] as String) : null,
      status: OrderStatus.fromString(map['status'] as String?),
      subtotal: (map['subtotal'] as num).toDouble(),
      discountAmount: (map['discountAmount'] as num? ?? 0.0).toDouble(),
      deliveryCharge: (map['deliveryCharge'] as num? ?? 0.0).toDouble(),
      grandTotal: (map['grandTotal'] as num).toDouble(),
      advanceAmount: (map['advanceAmount'] as num? ?? 0.0).toDouble(),
      balanceAmount: (map['balanceAmount'] as num).toDouble(),
      paymentStatus: PaymentStatus.fromString(map['paymentStatus'] as String?),
      notes: map['notes'] as String?,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.tryParse(map['deletedAt'] as String) : null,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      customer: customer,
      items: items,
      payments: payments,
    );
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    DateTime? orderDate,
    DateTime? deliveryDate,
    OrderStatus? status,
    double? subtotal,
    double? discountAmount,
    double? deliveryCharge,
    double? grandTotal,
    double? advanceAmount,
    double? balanceAmount,
    PaymentStatus? paymentStatus,
    String? notes,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Customer? customer,
    List<OrderItem>? items,
    List<Payment>? payments,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      grandTotal: grandTotal ?? this.grandTotal,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      payments: payments ?? this.payments,
    );
  }
}

class OrderFinancials {
  final double subtotal;
  final double discountAmount;
  final double deliveryCharge;
  final double grandTotal;
  final double advanceAmount;
  final double balanceAmount;
  final PaymentStatus paymentStatus;

  const OrderFinancials({
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryCharge,
    required this.grandTotal,
    required this.advanceAmount,
    required this.balanceAmount,
    required this.paymentStatus,
  });
}
