import '../core/log_entry.dart';
import '../config/format_config.dart';
import 'plain_text_formatter.dart';
import 'json_formatter.dart';
import 'compact_json_formatter.dart';
import 'csv_formatter.dart';

/// Base class for log formatters.
abstract class LogFormatter {
  const LogFormatter();

  /// Create formatter from config.
  factory LogFormatter.fromConfig(FormatConfig config) {
    switch (config.type) {
      case LogFormat.plainText:
        return PlainTextFormatter(timestampFormat: config.timestampFormat);
      case LogFormat.json:
        return const JsonFormatter();
      case LogFormat.compactJson:
        return const CompactJsonFormatter();
      case LogFormat.csv:
        return const CsvFormatter();
      case LogFormat.custom:
        if (config.customFormatter == null) {
          throw ArgumentError('customFormatter required for LogFormat.custom');
        }
        return _CustomFormatter(config.customFormatter!);
    }
  }

  /// Format a single log entry.
  String format(LogEntry entry);

  /// Format multiple entries with separator.
  String formatAll(List<LogEntry> entries) {
    return entries.map(format).join('\n');
  }

  /// Get file extension for this format.
  String get fileExtension;

  /// Get MIME type for this format.
  String get mimeType;
}

/// Wrapper for custom formatter function.
class _CustomFormatter extends LogFormatter {
  const _CustomFormatter(this._formatter);

  final CustomLogFormatter _formatter;

  @override
  String format(LogEntry entry) => _formatter(entry);

  @override
  String get fileExtension => 'log';

  @override
  String get mimeType => 'text/plain';
}
