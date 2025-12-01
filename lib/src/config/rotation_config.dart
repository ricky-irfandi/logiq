/// File rotation strategies.
enum RotationStrategy {
  /// Multiple files with rotation.
  /// current.log → backup_1.log → backup_2.log → deleted
  multiFile,

  /// Single file, trim oldest entries when full.
  singleFile,
}

/// Configuration for log file rotation.
class RotationConfig {
  const RotationConfig({
    this.strategy = RotationStrategy.multiFile,
    this.maxFileSize = 2 * 1024 * 1024, // 2MB
    this.maxFiles = 3,
    this.trimPercent = 25,
  });

  /// Create single-file rotation config.
  factory RotationConfig.singleFile({
    int maxFileSize = 5 * 1024 * 1024,
    int trimPercent = 25,
  }) =>
      RotationConfig(
        strategy: RotationStrategy.singleFile,
        maxFileSize: maxFileSize,
        trimPercent: trimPercent,
      );

  /// Create multi-file rotation config.
  factory RotationConfig.multiFile({
    int maxFileSize = 2 * 1024 * 1024,
    int maxFiles = 3,
  }) =>
      RotationConfig(
        strategy: RotationStrategy.multiFile,
        maxFileSize: maxFileSize,
        maxFiles: maxFiles,
      );

  /// Rotation strategy.
  final RotationStrategy strategy;

  /// Maximum file size in bytes before rotation.
  final int maxFileSize;

  /// Maximum number of backup files to keep (multiFile only).
  final int maxFiles;

  /// Percentage of oldest logs to trim when full (singleFile only).
  final int trimPercent;

  RotationConfig copyWith({
    RotationStrategy? strategy,
    int? maxFileSize,
    int? maxFiles,
    int? trimPercent,
  }) {
    return RotationConfig(
      strategy: strategy ?? this.strategy,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      maxFiles: maxFiles ?? this.maxFiles,
      trimPercent: trimPercent ?? this.trimPercent,
    );
  }
}
