import 'dart:convert';
import 'package:intl/intl.dart';
import '../core/log_entry.dart';
import 'log_formatter.dart';

/// Formats logs as human-readable plain text.
class PlainTextFormatter extends LogFormatter {
  PlainTextFormatter({String? timestampFormat})
      : _dateFormat =
            timestampFormat != null ? DateFormat(timestampFormat) : null;

  final DateFormat? _dateFormat;

  @override
  String format(LogEntry entry) {
    final buffer = StringBuffer();

    // Timestamp
    buffer.write('[');
    buffer.write(_formatTimestamp(entry.timestamp));
    buffer.write('] ');

    // Level
    buffer.write('[');
    buffer.write(entry.level.name.toUpperCase().padRight(7));
    buffer.write('] ');

    // Category
    buffer.write('[');
    buffer.write(entry.category);
    buffer.write('] ');

    // Message
    buffer.write(entry.message);

    // Context
    if (entry.context != null && entry.context!.isNotEmpty) {
      buffer.write(' ');
      buffer.write(jsonEncode(entry.context));
    }

    return buffer.toString();
  }

  String _formatTimestamp(DateTime timestamp) {
    final dateFormat = _dateFormat;
    if (dateFormat != null) {
      return dateFormat.format(timestamp);
    }
    return timestamp.toUtc().toIso8601String();
  }

  @override
  String get fileExtension => 'log';

  @override
  String get mimeType => 'text/plain';
}
