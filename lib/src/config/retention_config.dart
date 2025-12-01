/// Configuration for log retention and cleanup.
class RetentionConfig {
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
