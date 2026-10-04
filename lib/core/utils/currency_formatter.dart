import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat('#,##0.##');

  /// Formats amount with currency prefix.
  /// Example: format(15000, currency: 'PKR (Rs.)') -> "Rs. 15,000"
  static String format(num amount, {String currency = 'PKR (Rs.)'}) {
    final prefix = _getSymbol(currency);
    final formattedNumber = _formatter.format(amount);
    return '$prefix $formattedNumber';
  }

  /// Returns numeric format with commas without currency prefix.
  static String formatValue(num amount) {
    return _formatter.format(amount);
  }

  static String _getSymbol(String currency) {
    if (currency.contains('Rs') || currency.contains('PKR')) {
      return 'Rs.';
    }
    if (currency.contains('USD') || currency == '\$') {
      return '\$';
    }
    if (currency.contains('EUR') || currency == '€') {
      return '€';
    }
    if (currency.contains('GBP') || currency == '£') {
      return '£';
    }
    if (currency.contains('AED')) {
      return 'AED';
    }
    if (currency.contains('SAR')) {
      return 'SAR';
    }
    if (currency.contains('INR') || currency == '₹') {
      return '₹';
    }
    return currency;
  }
}
