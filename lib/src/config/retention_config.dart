/// Configuration for automatic log retention and cleanup.
///
/// Defines policies for automatically removing old log files to prevent
/// unbounded storage growth.
///
/// ## Example
///
/// ```dart
/// // Keep logs for 7 days (default)
/// RetentionConfig()
///
/// // Keep logs for 30 days, check every 12 hours
/// RetentionConfig(
///   maxAge: Duration(days: 30),
///   cleanupInterval: Duration(hours: 12),
/// )
/// ```
class RetentionConfig {
  /// Creates a retention configuration with the specified options.
  ///
  /// - [maxAge]: Maximum age of logs to keep (default: 7 days)
  /// - [minEntries]: Minimum entries to keep regardless of age (default: 100)
  /// - [cleanupInterval]: How often to run cleanup (default: 6 hours)
  const RetentionConfig({
    this.maxAge = const Duration(days: 7),
    this.minEntries = 100,
    this.cleanupInterval = const Duration(hours: 6),
  });

  /// Maximum age of logs to keep.
  final Duration maxAge;

  /// Minimum entries to keep regardless of age.
  final int minEntries;

  /// How often to run cleanup.
  final Duration cleanupInterval;

  /// Creates a copy of this configuration with the specified fields replaced.
  RetentionConfig copyWith({
    Duration? maxAge,
    int? minEntries,
    Duration? cleanupInterval,
  }) {
    return RetentionConfig(
      maxAge: maxAge ?? this.maxAge,
      minEntries: minEntries ?? this.minEntries,
      cleanupInterval: cleanupInterval ?? this.cleanupInterval,
    );
  }
}
