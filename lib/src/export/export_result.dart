import 'dart:io';

/// Result of a log export operation.
class ExportResult {
  const ExportResult({
    required this.file,
    required this.originalSize,
    required this.compressedSize,
    required this.entryCount,
    required this.startTime,
    required this.endTime,
  });

  /// Exported file.
  final File file;

  /// Original uncompressed size in bytes.
  final int originalSize;

  /// Compressed size in bytes.
  final int compressedSize;

  /// Number of log entries included.
  final int entryCount;

  /// Timestamp of oldest log in export.
  final DateTime startTime;

  /// Timestamp of newest log in export.
  final DateTime endTime;

  /// Time range of logs included (computed from start/end times).
  Duration get timeRange => endTime.difference(startTime);

  /// Get compression ratio (0.0 to 1.0).
  double get compressionRatio =>
      originalSize > 0 ? compressedSize / originalSize : 0.0;

  /// Get compression percentage saved.
  double get compressionPercent => (1.0 - compressionRatio) * 100;

  /// Get human-readable original size.
  String get formattedOriginalSize => _formatBytes(originalSize);

  /// Get human-readable compressed size.
  String get formattedCompressedSize => _formatBytes(compressedSize);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() {
    return 'ExportResult(\n'
        '  file: ${file.path}\n'
        '  originalSize: $formattedOriginalSize\n'
        '  compressedSize: $formattedCompressedSize\n'
        '  compression: ${compressionPercent.toStringAsFixed(1)}% saved\n'
        '  entryCount: $entryCount\n'
        '  timeRange: ${timeRange.inHours}h ${timeRange.inMinutes.remainder(60)}m\n'
        ')';
  }
}
