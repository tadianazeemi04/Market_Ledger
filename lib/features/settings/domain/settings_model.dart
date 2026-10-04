class AppSettings {
  final String companyName;
  final String salespersonName;
  final String salespersonPhone;
  final String currency;
  final int? userAge;
  final bool isOnboardingCompleted;
  final bool isDemoAccount;
  final bool hasSeenWorkflowTour;

  const AppSettings({
    this.companyName = '',
    this.salespersonName = '',
    this.salespersonPhone = '',
    this.currency = 'PKR (Rs.)',
    this.userAge,
    this.isOnboardingCompleted = false,
    this.isDemoAccount = false,
    this.hasSeenWorkflowTour = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'salespersonName': salespersonName,
      'salespersonPhone': salespersonPhone,
      'currency': currency,
      'userAge': userAge,
      'isOnboardingCompleted': isOnboardingCompleted ? 1 : 0,
      'isDemoAccount': isDemoAccount ? 1 : 0,
      'hasSeenWorkflowTour': hasSeenWorkflowTour ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      companyName: map['companyName'] as String? ?? '',
      salespersonName: map['salespersonName'] as String? ?? '',
      salespersonPhone: map['salespersonPhone'] as String? ?? '',
      currency: (map['currency'] as String?)?.isNotEmpty == true
          ? map['currency'] as String
          : 'PKR (Rs.)',
      userAge: map['userAge'] != null ? (map['userAge'] as num).toInt() : null,
      isOnboardingCompleted: (map['isOnboardingCompleted'] as int? ?? 0) == 1,
      isDemoAccount: (map['isDemoAccount'] as int? ?? 0) == 1,
      hasSeenWorkflowTour: (map['hasSeenWorkflowTour'] as int? ?? 0) == 1,
    );
  }

  AppSettings copyWith({
    String? companyName,
    String? salespersonName,
    String? salespersonPhone,
    String? currency,
    int? userAge,
    bool? isOnboardingCompleted,
    bool? isDemoAccount,
    bool? hasSeenWorkflowTour,
  }) {
    return AppSettings(
      companyName: companyName ?? this.companyName,
      salespersonName: salespersonName ?? this.salespersonName,
      salespersonPhone: salespersonPhone ?? this.salespersonPhone,
      currency: currency ?? this.currency,
      userAge: userAge ?? this.userAge,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      isDemoAccount: isDemoAccount ?? this.isDemoAccount,
      hasSeenWorkflowTour: hasSeenWorkflowTour ?? this.hasSeenWorkflowTour,
    );
  }
}
