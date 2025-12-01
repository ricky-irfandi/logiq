import 'log_level.dart';

/// Represents a single log entry.
class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.context,
    this.sessionId,
    this.sequenceNumber,
  });

  /// Create from JSON map.
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    final timestampStr = json['timestamp'];
    if (timestampStr == null) {
      throw const FormatException('Missing required field: timestamp');
    }
    final categoryStr = json['category'];
    if (categoryStr == null) {
      throw const FormatException('Missing required field: category');
    }
    final messageStr = json['message'];
    if (messageStr == null) {
      throw const FormatException('Missing required field: message');
    }

    return LogEntry(
      timestamp: DateTime.parse(timestampStr as String),
      level: LogLevel.tryParse(json['level'] as String) ?? LogLevel.info,
      category: categoryStr as String,
      message: messageStr as String,
      context: json['context'] as Map<String, dynamic>?,
      sessionId: json['sessionId'] as String?,
      sequenceNumber: json['seq'] as int?,
    );
  }

  /// Create from compact JSON map.
  factory LogEntry.fromCompactJson(Map<String, dynamic> json) {
    // Validate required fields
    final timestamp = json['t'];
    if (timestamp == null) {
      throw const FormatException('Missing required field: t (timestamp)');
    }
    final category = json['c'];
    if (category == null) {
      throw const FormatException('Missing required field: c (category)');
    }
    final message = json['m'];
    if (message == null) {
      throw const FormatException('Missing required field: m (message)');
    }

    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        timestamp as int,
        isUtc: true,
      ),
      level: LogLevel.fromValue(json['l'] as int) ?? LogLevel.info,
      category: category as String,
      message: message as String,
      context: json['x'] as Map<String, dynamic>?,
      sessionId: json['s'] as String?,
      sequenceNumber: json['n'] as int?,
    );
  }

  /// When the log was created.
  final DateTime timestamp;

  /// Severity level.
  final LogLevel level;

  /// Category/tag for grouping (e.g., 'API', 'BID', 'SOCKET').
  final String category;

  /// Log message.
  final String message;

  /// Additional context data.
  final Map<String, dynamic>? context;

  /// Session identifier for grouping logs.
  final String? sessionId;

  /// Sequence number for ordering.
  final int? sequenceNumber;

  /// Convert to full JSON map.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'level': level.name,
        'category': category,
        'message': message,
        if (context != null && context!.isNotEmpty) 'context': context,
        if (sessionId != null) 'sessionId': sessionId,
        if (sequenceNumber != null) 'seq': sequenceNumber,
      };

  /// Convert to compact JSON map (shortened keys).
  Map<String, dynamic> toCompactJson() => {
        't': timestamp.millisecondsSinceEpoch,
        'l': level.value,
        'c': category,
        'm': message,
        if (context != null && context!.isNotEmpty) 'x': context,
        if (sessionId != null) 's': sessionId,
        if (sequenceNumber != null) 'n': sequenceNumber,
      };

  /// Create a copy with modified fields.
  LogEntry copyWith({
    DateTime? timestamp,
    LogLevel? level,
    String? category,
    String? message,
    Map<String, dynamic>? context,
    String? sessionId,
    int? sequenceNumber,
  }) {
    return LogEntry(
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      category: category ?? this.category,
      message: message ?? this.message,
      context: context ?? this.context,
      sessionId: sessionId ?? this.sessionId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  @override
  String toString() => 'LogEntry(${level.name}, $category, $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          level == other.level &&
          category == other.category &&
          message == other.message &&
          sequenceNumber == other.sequenceNumber;

  @override
  int get hashCode =>
      Object.hash(timestamp, level, category, message, sequenceNumber);
}
