/// File rotation strategies.
enum RotationStrategy {
  /// Multiple files with rotation.
  /// current.log → backup_1.log → backup_2.log → deleted
  multiFile,

  /// Single file, trim oldest entries when full.
  singleFile,
}

/// Configuration for log file rotation and size management.
///
/// Controls how log files are managed when they reach size limits.
/// Two strategies are available:
///
/// - **Multi-file**: Rotates through multiple backup files
/// - **Single-file**: Trims oldest entries from a single file
///
/// ## Example
///
/// ```dart
/// // Multi-file rotation (default)
/// RotationConfig.multiFile(
///   maxFileSize: 5 * 1024 * 1024, // 5MB
///   maxFiles: 5,
/// )
///
/// // Single-file with trimming
/// RotationConfig.singleFile(
///   maxFileSize: 10 * 1024 * 1024, // 10MB
///   trimPercent: 30, // Remove 30% of oldest entries when full
/// )
/// ```
class RotationConfig {
  /// Creates a rotation configuration with the specified options.
  ///
  /// Defaults to multi-file strategy with 2MB files and 3 backup files.
  const RotationConfig({
    this.strategy = RotationStrategy.multiFile,
    this.maxFileSize = 2 * 1024 * 1024, // 2MB
    this.maxFiles = 3,
    this.trimPercent = 25,
  });

  /// Creates single-file rotation configuration.
  ///
  /// Uses a single log file that trims oldest entries when full.
  /// Good for constrained storage environments.
  factory RotationConfig.singleFile({
    int maxFileSize = 5 * 1024 * 1024,
    int trimPercent = 25,
  }) =>
      RotationConfig(
        strategy: RotationStrategy.singleFile,
        maxFileSize: maxFileSize,
        trimPercent: trimPercent,
      );

  /// Creates multi-file rotation configuration.
  ///
  /// Rotates through multiple backup files. When the current file reaches
  /// [maxFileSize], it becomes backup_1, backup_1 becomes backup_2, etc.
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

  /// Creates a copy of this configuration with the specified fields replaced.
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
