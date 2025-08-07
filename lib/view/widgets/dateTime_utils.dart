import 'package:intl/intl.dart';

/// A utility class for formatting dates and times consistently across the app.
class DateFormatter {
  /// Formats full [DateTime] with time.
  /// Example output: "Aug 8, 2025 11:30 PM"
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, y h:mm a').format(dateTime);
  }

  /// Formats only the date part of [DateTime].
  /// Example output: "Aug 8, 2025"
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('MMM d, y').format(dateTime);
  }
}
