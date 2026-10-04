class SavedAccount {
  final String id;
  final String salespersonName;
  final String companyName;
  final String salespersonPhone;
  final int? userAge;
  final String currency;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const SavedAccount({
    required this.id,
    required this.salespersonName,
    required this.companyName,
    this.salespersonPhone = '',
    this.userAge,
    this.currency = 'PKR (Rs.)',
    required this.createdAt,
    required this.lastActiveAt,
  });

  Map<String, dynamic> toMap({String? snapshotJson}) {
    return {
      'id': id,
      'salespersonName': salespersonName,
      'companyName': companyName,
      'salespersonPhone': salespersonPhone,
      'userAge': userAge,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'snapshotJson': ?snapshotJson,
    };
  }

  factory SavedAccount.fromMap(Map<String, dynamic> map) {
    return SavedAccount(
      id: map['id'] as String,
      salespersonName: map['salespersonName'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      salespersonPhone: map['salespersonPhone'] as String? ?? '',
      userAge: map['userAge'] != null ? (map['userAge'] as num).toInt() : null,
      currency: map['currency'] as String? ?? 'PKR (Rs.)',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastActiveAt: DateTime.tryParse(map['lastActiveAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
