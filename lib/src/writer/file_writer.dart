import 'dart:io';
import 'dart:convert';
import '../config/format_config.dart';
import '../config/rotation_config.dart';
import '../format/log_formatter.dart';
import '../format/plain_text_formatter.dart';
import '../format/json_formatter.dart';
import '../format/compact_json_formatter.dart';
import '../format/csv_formatter.dart';
import '../security/log_redactor.dart';
import '../security/log_encryptor.dart';
import '../security/redaction_pattern.dart';
import 'write_params.dart';

/// Handles file writing in isolate.
class FileWriter {
  /// Write entries to file (called via compute).
  /// This is the entry point for isolate work.
  static Future<bool> writeEntries(Map<String, dynamic> paramsMap) async {
    final params = WriteParams.fromMap(paramsMap);
    LogEncryptor? encryptor;
    var rotated = false;

    try {
      // 1. Setup components
      final formatter = _createFormatter(params.formatType);
      final redactor = _createRedactor(params.redactionPatterns);
      encryptor = params.encryptionKey != null
          ? LogEncryptor(params.encryptionKey!)
          : null;

      // 2-4. Process entries in single pass: redact → format → encrypt
      final dataLines = params.entries.map((entry) {
        // Redact
        final redacted = redactor.redact(entry);
        // Format
        final formatted = formatter.format(redacted);
        // Encrypt if needed
        if (encryptor != null) {
          return base64Encode(encryptor.encrypt(formatted));
        }
        return formatted;
      });

      // 5. Write to file
      final logFile = File('${params.logDirectory}/current.log');
      await logFile.parent.create(recursive: true);

      // Write all lines in one operation
      final dataToWrite = '${dataLines.join('\n')}\n';
      await logFile.writeAsString(dataToWrite, mode: FileMode.append);

      // 6. Check rotation
      rotated = await _checkRotation(
        logFile: logFile,
        params: params,
      );
    } catch (e) {
      // Silent fail in isolate - don't crash
      // The main thread will detect write failures via stats
    } finally {
      // Always dispose encryptor to zero key material
      encryptor?.dispose();
    }
    return rotated;
  }

  static LogFormatter _createFormatter(int formatType) {
    final format = LogFormat.values[formatType];
    switch (format) {
      case LogFormat.plainText:
        return PlainTextFormatter();
      case LogFormat.json:
        return const JsonFormatter();
      case LogFormat.compactJson:
        return const CompactJsonFormatter();
      case LogFormat.csv:
        return const CsvFormatter();
      case LogFormat.custom:
        // Custom formatter can't be passed to isolate, fallback to JSON
        return const JsonFormatter();
    }
  }

  static LogRedactor _createRedactor(List<Map<String, dynamic>> patterns) {
    final redactionPatterns = patterns
        .map(
          (p) => RedactionPattern(
            name: p['name'] as String,
            pattern: RegExp(p['pattern'] as String),
            replacement: p['replacement'] as String,
          ),
        )
        .toList();
    return LogRedactor(redactionPatterns);
  }

  static Future<bool> _checkRotation({
    required File logFile,
    required WriteParams params,
  }) async {
    try {
      if (!await logFile.exists()) return false;

      final size = await logFile.length();
      if (size < params.maxFileSize) return false;

      final strategy = RotationStrategy.values[params.rotationStrategy];

      switch (strategy) {
        case RotationStrategy.multiFile:
          await _rotateMultiFile(logFile, params);
          return true;
        case RotationStrategy.singleFile:
          await _trimSingleFile(logFile, params);
          return true;
      }
    } catch (e) {
      // Silent fail - rotation errors shouldn't crash logging
    }
    return false;
  }

  static Future<void> _rotateMultiFile(
    File logFile,
    WriteParams params,
  ) async {
    final dir = logFile.parent;

    // Delete oldest backup if at limit
    final oldestBackup = File('${dir.path}/backup_${params.maxFiles}.log');
    if (await oldestBackup.exists()) {
      await oldestBackup.delete();
    }

    // Rotate existing backups (move backward)
    for (var i = params.maxFiles - 1; i >= 1; i--) {
      final backup = File('${dir.path}/backup_$i.log');
      if (await backup.exists()) {
        await backup.rename('${dir.path}/backup_${i + 1}.log');
      }
    }

    // Move current to backup_1
    await logFile.rename('${dir.path}/backup_1.log');

    // Create new current.log
    await File('${dir.path}/current.log').create();
  }

  static Future<void> _trimSingleFile(File logFile, WriteParams params) async {
    try {
      // Use streaming to prevent OOM on large files
      final lines = <String>[];

      // Read file line by line using stream (memory-efficient)
      await for (final line in logFile
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isNotEmpty) {
          lines.add(line);
        }
      }

      if (lines.isEmpty) return;

      var remaining = lines;
      // Iteratively trim until under size or minimal lines remain
      while (remaining.length > 10) {
        final estimatedSize =
            remaining.fold<int>(remaining.length, (s, l) => s + l.length);
        if (estimatedSize <= params.maxFileSize) break;

        final linesToRemove =
            (remaining.length * params.trimPercent / 100).ceil();
        final safeRemove = linesToRemove >= remaining.length
            ? remaining.length - 10
            : linesToRemove;
        remaining = remaining.skip(safeRemove).toList();
      }

      await logFile.writeAsString('${remaining.join('\n')}\n');
    } catch (e) {
      // If trim fails, just clear the file to prevent infinite growth
      await logFile.writeAsString('');
    }
  }
}
