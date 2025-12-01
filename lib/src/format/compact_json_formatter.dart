import 'dart:convert';
import '../core/log_entry.dart';
import 'log_formatter.dart';

/// Formats logs as compact JSON with shortened keys.
class CompactJsonFormatter extends LogFormatter {
  const CompactJsonFormatter();

  @override
  String format(LogEntry entry) {
    return jsonEncode(entry.toCompactJson());
  }

  @override
  String get fileExtension => 'jsonl';

  @override
  String get mimeType => 'application/x-ndjson';
}
