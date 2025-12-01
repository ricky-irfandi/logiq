import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/logiq.dart';

/// Test helper utilities for Logiq tests.
class TestHelpers {
  /// Create a test log entry with default values.
  static LogEntry createTestLogEntry({
    DateTime? timestamp,
    LogLevel level = LogLevel.info,
    String category = 'TEST',
    String message = 'Test message',
    Map<String, dynamic>? context,
    String? sessionId,
    int? sequenceNumber,
  }) {
    return LogEntry(
      timestamp: timestamp ?? DateTime.now(),
      level: level,
      category: category,
      message: message,
      context: context,
      sessionId: sessionId,
      sequenceNumber: sequenceNumber,
    );
  }

  /// Create a temporary directory for testing.
  /// Returns the directory and a cleanup function.
  static Future<Directory> createTempDirectory({String? prefix}) async {
    final tempDir =
        await Directory.systemTemp.createTemp(prefix ?? 'logiq_test_');
    return tempDir;
  }

  /// Cleanup temporary directory.
  static Future<void> cleanupDirectory(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Wait for a condition with timeout.
  static Future<void> waitFor(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (!await condition()) {
      if (DateTime.now().isAfter(endTime)) {
        throw TimeoutException('Condition not met within timeout');
      }
      await Future.delayed(checkInterval);
    }
  }

  /// Wait for flush to complete with timeout.
  static Future<void> waitForFlush({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Give some time for flush to trigger and complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Read and parse a log file.
  static Future<String> readLogFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Log file does not exist: $path');
    }
    return await file.readAsString();
  }

  /// Check if a log file exists.
  static Future<bool> logFileExists(String directory, String filename) async {
    final file = File('$directory/$filename');
    return file.exists();
  }

  /// Count log files in directory.
  static Future<int> countLogFiles(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return 0;

    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.log')) {
        count++;
      }
    }
    return count;
  }

  /// Generate a random encryption key (32 bytes for AES-256).
  static Uint8List generateTestKey() {
    return Uint8List.fromList(
      List.generate(32, (i) => i % 256),
    );
  }

  /// Create a test LogConfig with custom directory.
  static LogConfig createTestConfig({
    required String directory,
    LogLevel minLevel = LogLevel.verbose,
    int bufferSize = 100,
    Duration flushInterval = const Duration(seconds: 1),
    FormatConfig format = const FormatConfig(),
    RotationConfig rotation = const RotationConfig(),
    EncryptionConfig? encryption,
    List<RedactionPattern> redactionPatterns = const [],
  }) {
    return LogConfig(
      directory: directory,
      minLevel: minLevel,
      bufferSize: bufferSize,
      flushInterval: flushInterval,
      format: format,
      rotation: rotation,
      encryption: encryption,
      redactionPatterns: redactionPatterns,
      debugViewer: const DebugViewerConfig(enabled: false),
    );
  }
}

/// Custom matchers for testing.

/// Matcher that checks if a file exists.
Matcher fileExists() => _FileExistsMatcher();

/// Matcher that checks if a directory exists.
Matcher directoryExists() => _DirectoryExistsMatcher();

/// Matcher that checks if a log string contains specific text.
Matcher logContains(String text) => contains(text);

class _FileExistsMatcher extends Matcher {
  @override
  Description describe(Description description) =>
      description.add('file exists');

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! File) return false;
    return item.existsSync();
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! File) {
      return mismatchDescription.add('is not a File');
    }
    return mismatchDescription.add('does not exist');
  }
}

class _DirectoryExistsMatcher extends Matcher {
  @override
  Description describe(Description description) =>
      description.add('directory exists');

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Directory) return false;
    return item.existsSync();
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! Directory) {
      return mismatchDescription.add('is not a Directory');
    }
    return mismatchDescription.add('does not exist');
  }
}
