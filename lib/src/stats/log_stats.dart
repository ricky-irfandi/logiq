/// Statistics about logging activity.
class LogStats {
  const LogStats({
    required this.totalLogged,
    required this.bufferedCount,
    required this.droppedCount,
    required this.writeFailures,
    required this.storageUsed,
    required this.fileCount,
    this.oldestEntry,
    this.newestEntry,
    required this.sessionId,
  });

  /// Total number of logs created in this session.
  final int totalLogged;

  /// Number of logs currently in memory buffer.
  final int bufferedCount;

  /// Number of logs dropped due to buffer overflow.
  final int droppedCount;

  /// Number of failed write attempts.
  final int writeFailures;

  /// Total storage used by log files in bytes.
  final int storageUsed;

  /// Number of log files on disk.
  final int fileCount;

  /// Timestamp of oldest log file.
  final DateTime? oldestEntry;

  /// Timestamp of newest log file.
  final DateTime? newestEntry;

  /// Current session identifier.
  final String sessionId;

  /// Get human-readable storage size.
  String get formattedStorageSize {
    if (storageUsed < 1024) return '$storageUsed B';
    if (storageUsed < 1024 * 1024) {
      return '${(storageUsed / 1024).toStringAsFixed(2)} KB';
    }
    if (storageUsed < 1024 * 1024 * 1024) {
      return '${(storageUsed / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(storageUsed / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() {
    return 'LogStats(\n'
        '  totalLogged: $totalLogged\n'
        '  bufferedCount: $bufferedCount\n'
        '  droppedCount: $droppedCount\n'
        '  writeFailures: $writeFailures\n'
        '  storageUsed: $formattedStorageSize\n'
        '  fileCount: $fileCount\n'
        '  sessionId: $sessionId\n'
        ')';
  }
}
