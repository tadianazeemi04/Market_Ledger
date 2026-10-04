library;

/// Enums for MarketLedger order, payment, and filter status.

enum OrderStatus {
  draft('Draft'),
  confirmed('Confirmed'),
  processing('Processing'),
  delivered('Delivered'),
  cancelled('Cancelled');

  final String label;
  const OrderStatus(this.label);

  static OrderStatus fromString(String? value) {
    if (value == null) return OrderStatus.draft;
    return OrderStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase() || e.label.toLowerCase() == value.toLowerCase(),
      orElse: () => OrderStatus.draft,
    );
  }
}

enum PaymentStatus {
  unpaid('Unpaid'),
  partial('Partial'),
  paid('Paid');

  final String label;
  const PaymentStatus(this.label);

  static PaymentStatus fromString(String? value) {
    if (value == null) return PaymentStatus.unpaid;
    return PaymentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase() || e.label.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentStatus.unpaid,
    );
  }

  /// Calculates payment status from grand total and advance/paid amount.
  static PaymentStatus calculate(double grandTotal, double paidAmount) {
    if (paidAmount <= 0.001) {
      return PaymentStatus.unpaid;
    } else if (paidAmount >= (grandTotal - 0.001)) {
      return PaymentStatus.paid;
    } else {
      return PaymentStatus.partial;
    }
  }
}

enum PaymentMethod {
  cash('Cash'),
  bankTransfer('Bank Transfer'),
  mobileWallet('JazzCash/EasyPaisa'),
  cheque('Cheque'),
  other('Other');

  final String label;
  const PaymentMethod(this.label);

  static PaymentMethod fromString(String? value) {
    if (value == null) return PaymentMethod.cash;
    return PaymentMethod.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase() || e.label.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentMethod.cash,
    );
  }
}
