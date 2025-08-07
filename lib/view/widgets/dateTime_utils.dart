import 'package:intl/intl.dart';

/// A utility class for formatting dates and times with day-month-year order.
class DateFormatter {
  /// Formats full [DateTime] with time.
  /// Example output: "08 Aug 2025 11:30 PM"
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd MMM y h:mm a').format(dateTime);
  }

  /// Formats only the date part of [DateTime].
  /// Example output: "08 Aug 2025"
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd MMM y').format(dateTime);
  }
}
