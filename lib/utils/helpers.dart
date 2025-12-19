import 'package:intl/intl.dart';

class Helpers {
  // Format date
  static String formatDate(DateTime date, {String format = 'dd/MM/yyyy'}) {
    return DateFormat(format).format(date);
  }

  // Format time
  static String formatTime(DateTime time, {String format = 'HH:mm:ss'}) {
    return DateFormat(format).format(time);
  }

  // Get greeting based on time
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  // Convert dynamic to bool
  static bool toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.toLowerCase();
      return s == 'on' || s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  // Convert dynamic to double
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Extract nested value from map
  static dynamic extract(Map map, List<String> path) {
    dynamic current = map;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  // Temperature label
  static String getTemperatureLabel(double? temperature) {
    if (temperature == null) return '';
    if (temperature > 25) return 'Warm';
    if (temperature > 20) return 'Comfortable';
    return 'Cool';
  }

  // Humidity label
  static String getHumidityLabel(double? humidity) {
    if (humidity == null) return '';
    if (humidity > 60) return 'High';
    if (humidity > 40) return 'Normal';
    return 'Low';
  }

  // Validate email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  // Validate password
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Safe print (replaces debugPrint)
  static void safePrint(String message) {
    print(message);
  }
}
