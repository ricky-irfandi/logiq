import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../security/log_encryptor.dart';
import 'export_result.dart';

/// Handles exporting logs to compressed archives.
class LogExporter {
  // Limit export size to prevent OOM on low-end devices
  static const int _maxExportSizeBytes = 50 * 1024 * 1024; // 50MB uncompressed

  /// Export logs to a compressed archive.
  static Future<ExportResult> export({
    required String logDirectory,
    Duration? timeRange,
    bool compress = true,
    bool includeDeviceInfo = true,
    Uint8List? encryptionKey,
  }) async {
    final dir = Directory(logDirectory);
    if (!await dir.exists()) {
      throw StateError('Log directory does not exist: $logDirectory');
    }

    // Collect log files
    final logFiles = <File>[];
    final cutoffTime =
        timeRange != null ? DateTime.now().subtract(timeRange) : null;
    var totalSize = 0;

    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.log')) {
        if (cutoffTime != null) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffTime)) continue;
        }
        // Check size before adding to prevent OOM
        final stat = await file.stat();
        totalSize += stat.size;
        if (totalSize > _maxExportSizeBytes) {
          throw StateError(
            'Export size exceeds limit (${_maxExportSizeBytes ~/ (1024 * 1024)}MB). '
            'Use timeRange parameter to export smaller range.',
          );
        }
        logFiles.add(file);
      }
    }

    if (logFiles.isEmpty) {
      throw StateError('No log files found to export');
    }

    // Collect logs content
    final logsContent = StringBuffer();
    var originalSize = 0;
    var entryCount = 0;
    DateTime? oldestEntry;
    DateTime? newestEntry;
    LogEncryptor? encryptor;

    try {
      encryptor = encryptionKey != null ? LogEncryptor(encryptionKey) : null;

      for (final file in logFiles) {
        final content = await file.readAsString();
        final stat = await file.stat();

        // Decrypt if encrypted (line by line)
        String decryptedContent;
        if (encryptor != null && content.trim().isNotEmpty) {
          final lines = content.split('\n');
          final decryptedLines = <String>[];

          for (final line in lines) {
            if (line.trim().isEmpty) continue;

            try {
              final encrypted = base64Decode(line.trim());
              final decrypted = encryptor.decrypt(encrypted);
              decryptedLines.add(decrypted);
            } catch (_) {
              // If decryption fails, include the line as-is
              // (might be plain text log)
              decryptedLines.add(line);
            }
          }
          decryptedContent = decryptedLines.join('\n');
        } else {
          decryptedContent = content;
        }

        originalSize += decryptedContent.length;
        entryCount += decryptedContent
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .length;

        if (oldestEntry == null || stat.modified.isBefore(oldestEntry)) {
          oldestEntry = stat.modified;
        }
        if (newestEntry == null || stat.modified.isAfter(newestEntry)) {
          newestEntry = stat.modified;
        }

        logsContent.writeln('=== ${p.basename(file.path)} ===');
        logsContent.writeln(decryptedContent);
        logsContent.writeln();
      }

      // Add device info if requested
      if (includeDeviceInfo) {
        final deviceInfo = _generateDeviceInfo();
        logsContent.writeln('=== Device Info ===');
        logsContent.writeln(deviceInfo);
        logsContent.writeln();
      }

      // Create export file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final exportFileName = 'logiq_export_$timestamp';

      File exportFile;
      var compressedSize = originalSize;

      if (compress) {
        // Create GZip archive with fallback if compression fails
        final contentBytes = utf8.encode(logsContent.toString());
        try {
          final gzipBytes = const GZipEncoder().encode(contentBytes);
          exportFile = File('${tempDir.path}/$exportFileName.log.gz');
          await exportFile.writeAsBytes(gzipBytes);
          compressedSize = gzipBytes.length;
        } catch (e) {
          // Fallback to uncompressed if GZip encoding fails
          if (kDebugMode) {
            debugPrint(
              'Logiq: GZip compression failed: $e. Using uncompressed export.',
            );
          }
          exportFile = File('${tempDir.path}/$exportFileName.log');
          await exportFile.writeAsString(logsContent.toString());
          compressedSize = contentBytes.length;
        }
      } else {
        exportFile = File('${tempDir.path}/$exportFileName.log');
        await exportFile.writeAsString(logsContent.toString());
        compressedSize = logsContent.toString().length;
      }

      return ExportResult(
        file: exportFile,
        originalSize: originalSize,
        compressedSize: compressedSize,
        entryCount: entryCount,
        startTime: oldestEntry ?? DateTime.now(),
        endTime: newestEntry ?? DateTime.now(),
      );
    } finally {
      // Always dispose encryptor to zero key material
      encryptor?.dispose();
    }
  }

  static String _generateDeviceInfo() {
    return '''
Export Date: ${DateTime.now().toIso8601String()}
Platform: ${Platform.operatingSystem}
OS Version: ${Platform.operatingSystemVersion}
Dart Version: ${Platform.version}
''';
  }
}
