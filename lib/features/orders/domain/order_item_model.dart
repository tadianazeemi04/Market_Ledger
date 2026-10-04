class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productNameSnapshot;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountAmount;
  final double lineTotal;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.discountAmount = 0.0,
    required this.lineTotal,
  });

  static double computeLineTotal(double quantity, double unitPrice, double discountAmount) {
    final raw = (quantity * unitPrice) - discountAmount;
    return raw > 0 ? raw : 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'productNameSnapshot': productNameSnapshot,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'discountAmount': discountAmount,
      'lineTotal': lineTotal,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      productId: map['productId'] as String,
      productNameSnapshot: map['productNameSnapshot'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: (map['unit'] as String?) ?? 'pcs',
      unitPrice: (map['unitPrice'] as num).toDouble(),
      discountAmount: (map['discountAmount'] as num? ?? 0.0).toDouble(),
      lineTotal: (map['lineTotal'] as num).toDouble(),
    );
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productNameSnapshot,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? discountAmount,
    double? lineTotal,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productNameSnapshot: productNameSnapshot ?? this.productNameSnapshot,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
}
