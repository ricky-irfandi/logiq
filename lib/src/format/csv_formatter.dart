import 'dart:convert';
import '../core/log_entry.dart';
import 'log_formatter.dart';

/// Formats logs as CSV.
class CsvFormatter extends LogFormatter {
  const CsvFormatter();

  /// CSV header row.
  static const String header =
      'timestamp,level,category,message,context,sessionId';

  @override
  String format(LogEntry entry) {
    final fields = [
      entry.timestamp.toUtc().toIso8601String(),
      entry.level.name,
      _escape(entry.category),
      _escape(entry.message),
      _escape(entry.context != null ? jsonEncode(entry.context) : ''),
      entry.sessionId ?? '',
    ];
    return fields.join(',');
  }

  @override
  String formatAll(List<LogEntry> entries) {
    final lines = [header, ...entries.map(format)];
    return lines.join('\n');
  }

  /// Escape CSV field if needed.
  String _escape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  @override
  String get fileExtension => 'csv';

  @override
  String get mimeType => 'text/csv';
}
