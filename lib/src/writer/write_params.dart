import 'dart:typed_data';
import '../core/log_entry.dart';
import '../config/log_config.dart';

/// Parameters passed to file writer isolate.
class WriteParams {
  const WriteParams({
    required this.entries,
    required this.logDirectory,
    required this.formatType,
    required this.rotationStrategy,
    required this.maxFileSize,
    required this.maxFiles,
    required this.trimPercent,
    required this.redactionPatterns,
    this.encryptionKey,
  });

  /// Create from map.
  factory WriteParams.fromMap(Map<String, dynamic> map) {
    return WriteParams(
      entries: (map['entries'] as List)
          .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      logDirectory: map['logDirectory'] as String,
      formatType: map['formatType'] as int,
      rotationStrategy: map['rotationStrategy'] as int,
      maxFileSize: map['maxFileSize'] as int,
      maxFiles: map['maxFiles'] as int,
      trimPercent: map['trimPercent'] as int,
      redactionPatterns:
          (map['redactionPatterns'] as List).cast<Map<String, dynamic>>(),
      encryptionKey: map['encryptionKey'] != null
          ? Uint8List.fromList((map['encryptionKey'] as List).cast<int>())
          : null,
    );
  }

  final List<LogEntry> entries;
  final String logDirectory;
  final int formatType; // LogFormat.index
  final int rotationStrategy; // RotationStrategy.index
  final int maxFileSize;
  final int maxFiles;
  final int trimPercent;
  final List<Map<String, dynamic>> redactionPatterns;
  final Uint8List? encryptionKey;

  /// Create from config and entries.
  static Future<WriteParams> fromConfig({
    required List<LogEntry> entries,
    required String logDirectory,
    required LogConfig config,
  }) async {
    Uint8List? encryptionKey;
    if (config.encryption?.enabled == true) {
      encryptionKey = await config.encryption!.getKey();
    }

    return WriteParams(
      entries: entries,
      logDirectory: logDirectory,
      formatType: config.format.type.index,
      rotationStrategy: config.rotation.strategy.index,
      maxFileSize: config.rotation.maxFileSize,
      maxFiles: config.rotation.maxFiles,
      trimPercent: config.rotation.trimPercent,
      redactionPatterns: config.redactionPatterns
          .map(
            (p) => {
              'name': p.name,
              'pattern': p.pattern.pattern,
              'replacement': p.replacement,
            },
          )
          .toList(),
      encryptionKey: encryptionKey,
    );
  }

  /// Convert to map for isolate transfer.
  Map<String, dynamic> toMap() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'logDirectory': logDirectory,
        'formatType': formatType,
        'rotationStrategy': rotationStrategy,
        'maxFileSize': maxFileSize,
        'maxFiles': maxFiles,
        'trimPercent': trimPercent,
        'redactionPatterns': redactionPatterns,
        'encryptionKey': encryptionKey
            ?.toList(), // Convert Uint8List to List for serialization
      };
}
