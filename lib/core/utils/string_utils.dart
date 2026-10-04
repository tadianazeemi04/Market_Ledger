import '../../features/settings/domain/settings_model.dart';

class StringUtils {
  StringUtils._();

  /// Capitalizes the first letter of each word in [text].
  /// Example: "tariq mehmood" -> "Tariq Mehmood"
  /// Example: "JOHN DOE" -> "John Doe"
  static String toTitleCase(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return '';

    return raw.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return '';
      // Support hyphenated names e.g. "al-madina" -> "Al-Madina"
      if (w.contains('-')) {
        return w.split('-').map((part) {
          if (part.isEmpty) return '';
          return part[0].toUpperCase() + (part.length > 1 ? part.substring(1).toLowerCase() : '');
        }).join('-');
      }
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).where((w) => w.isNotEmpty).join(' ');
  }

  /// Formats the salesperson greeting display name:
  /// - In Demo Mode: returns "App Reviewer"
  /// - In User Account: returns full name with every word's first letter capitalized
  /// - Fallback: "Salesperson"
  static String formatGreetingName(AppSettings settings, {String fallback = 'Salesperson'}) {
    if (settings.isDemoAccount) {
      return 'App Reviewer';
    }
    final rawName = settings.salespersonName.trim();
    if (rawName.isEmpty) return fallback;

    final formatted = toTitleCase(rawName);
    return formatted.isNotEmpty ? formatted : fallback;
  }
}
