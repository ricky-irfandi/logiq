import 'dart:convert';
import '../core/log_entry.dart';
import 'log_formatter.dart';

/// Formats logs as JSON (NDJSON - one object per line).
class JsonFormatter extends LogFormatter {
  const JsonFormatter();

  @override
  String format(LogEntry entry) {
    return jsonEncode(entry.toJson());
  }

  @override
  String get fileExtension => 'jsonl';

  @override
  String get mimeType => 'application/x-ndjson';
}
