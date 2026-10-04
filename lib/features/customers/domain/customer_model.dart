class Customer {
  final String id;
  final String shopName;
  final String ownerName;
  final String phone;
  final String marketArea;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional transient aggregations (computed from orders)
  final int totalOrders;
  final double totalSpent;
  final DateTime? lastOrderDate;

  const Customer({
    required this.id,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.marketArea,
    required this.address,
    this.latitude,
    this.longitude,
    this.notes,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.lastOrderDate,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopName': shopName,
      'ownerName': ownerName,
      'phone': phone,
      'marketArea': marketArea,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      shopName: map['shopName'] as String,
      ownerName: map['ownerName'] as String,
      phone: (map['phone'] as String?) ?? '',
      marketArea: (map['marketArea'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      notes: map['notes'] as String?,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] != null ? DateTime.tryParse(map['deletedAt'] as String) : null,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      totalOrders: map['totalOrders'] != null ? (map['totalOrders'] as num).toInt() : 0,
      totalSpent: map['totalSpent'] != null ? (map['totalSpent'] as num).toDouble() : 0.0,
      lastOrderDate: map['lastOrderDate'] != null ? DateTime.tryParse(map['lastOrderDate'] as String) : null,
    );
  }

  Customer copyWith({
    String? id,
    String? shopName,
    String? ownerName,
    String? phone,
    String? marketArea,
    String? address,
    double? latitude,
    double? longitude,
    String? notes,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalOrders,
    double? totalSpent,
    DateTime? lastOrderDate,
  }) {
    return Customer(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      marketArea: marketArea ?? this.marketArea,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
    );
  }
}
