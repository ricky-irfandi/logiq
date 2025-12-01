import '../core/log_entry.dart';

/// Log output formats.
enum LogFormat {
  /// Human-readable plain text.
  /// Example: [2025-01-15T10:30:45.123Z] [INFO] [BID] User placed bid {id: 123}
  plainText,

  /// Full JSON (NDJSON - one object per line).
  /// Example: {"timestamp":"2025-01-15T10:30:45.123Z","level":"INFO",...}
  json,

  /// Compact JSON with shortened keys.
  /// Example: {"t":1705312245123,"l":2,"c":"BID","m":"..."}
  compactJson,

  /// CSV format for spreadsheet analysis.
  /// Example: 2025-01-15T10:30:45.123Z,INFO,BID,"User placed bid","{...}"
  csv,

  /// Custom format using provided formatter.
  custom,
}

/// Custom formatter function type.
typedef CustomLogFormatter = String Function(LogEntry entry);

/// Configuration for log formatting.
class FormatConfig {
  const FormatConfig({
    this.type = LogFormat.json,
    this.customFormatter,
    this.timestampFormat,
    this.includeSessionId = true,
    this.includeSequenceNumber = true,
  });

  /// Create plain text format config.
  factory FormatConfig.plainText({String? timestampFormat}) => FormatConfig(
        type: LogFormat.plainText,
        timestampFormat: timestampFormat,
      );

  /// Create JSON format config.
  const factory FormatConfig.json() = FormatConfig;

  /// Create compact JSON format config.
  factory FormatConfig.compactJson() => const FormatConfig(
        type: LogFormat.compactJson,
      );

  /// Create CSV format config.
  factory FormatConfig.csv() => const FormatConfig(
        type: LogFormat.csv,
      );

  /// Create custom format config.
  factory FormatConfig.custom(CustomLogFormatter formatter) => FormatConfig(
        type: LogFormat.custom,
        customFormatter: formatter,
      );

  /// Format type.
  final LogFormat type;

  /// Custom formatter (required when type is [LogFormat.custom]).
  final CustomLogFormatter? customFormatter;

  /// Custom timestamp format (only for plainText).
  /// Uses intl DateFormat pattern.
  final String? timestampFormat;

  /// Whether to include session ID in output.
  final bool includeSessionId;

  /// Whether to include sequence number in output.
  final bool includeSequenceNumber;

  FormatConfig copyWith({
    LogFormat? type,
    CustomLogFormatter? customFormatter,
    String? timestampFormat,
    bool? includeSessionId,
    bool? includeSequenceNumber,
  }) {
    return FormatConfig(
      type: type ?? this.type,
      customFormatter: customFormatter ?? this.customFormatter,
      timestampFormat: timestampFormat ?? this.timestampFormat,
      includeSessionId: includeSessionId ?? this.includeSessionId,
      includeSequenceNumber:
          includeSequenceNumber ?? this.includeSequenceNumber,
    );
  }
}
