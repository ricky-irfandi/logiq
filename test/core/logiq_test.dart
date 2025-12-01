import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:logiq/logiq.dart';
import '../helpers/test_helpers.dart';
import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Logiq', () {
    late Directory tempDir;
    late String logDirectory;

    setUp(() async {
      tempDir = await TestHelpers.createTempDirectory();
      logDirectory = '${tempDir.path}/logs';
    });

    tearDown(() async {
      // Dispose Logiq if initialized
      try {
        await Logiq.dispose();
      } catch (_) {
        // Not initialized, ignore
      }

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('initialization', () {
      test('should initialize with default config', () async {
        await Logiq.init();

        expect(Logiq.isEnabled, isTrue);
        expect(Logiq.logDirectory, isNotEmpty);
      });

      test('should initialize with custom config', () async {
        await Logiq.init(
          config: LogConfig(
            minLevel: LogLevel.warning,
            bufferSize: 100,
            directory: logDirectory,
          ),
        );

        expect(Logiq.logDirectory, logDirectory);
        expect(Logiq.config.minLevel, LogLevel.warning);
        expect(Logiq.config.bufferSize, 100);
      });

      test('should create log directory on init', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        expect(Directory(logDirectory), await directoryExists());
      });

      test('should not reinitialize if already initialized', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        final firstDir = Logiq.logDirectory;

        // Try to init again with different directory
        await Logiq.init(
          config: LogConfig(directory: '${tempDir.path}/other'),
        );

        // Directory should not change
        expect(Logiq.logDirectory, firstDir);
      });

      test('should use LogConfig.auto() by default', () async {
        await Logiq.init();

        // Should have some config loaded
        expect(Logiq.config, isNotNull);
      });

      test('should use LogConfig.debug() config', () async {
        await Logiq.init(config: LogConfig.debug());

        expect(Logiq.config.minLevel, LogLevel.verbose);
        expect(Logiq.config.debugViewer.enabled, isTrue);
      });

      test('should use LogConfig.production() config', () async {
        await Logiq.init(config: LogConfig.production());

        expect(Logiq.config.minLevel, LogLevel.info);
        expect(Logiq.config.debugViewer.enabled, isFalse);
      });
    });

    group('logging methods', () {
      setUp(() async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            minLevel: LogLevel.verbose,
            flushInterval: const Duration(seconds: 1),
          ),
        );
      });

      test('should log verbose message', () async {
        Logiq.v('TEST', 'Verbose message');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Verbose message'));
      });

      test('should log debug message', () async {
        Logiq.d('TEST', 'Debug message');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Debug message'));
      });

      test('should log info message', () async {
        Logiq.i('TEST', 'Info message');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Info message'));
      });

      test('should log warning message', () async {
        Logiq.w('TEST', 'Warning message');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Warning message'));
      });

      test('should log error message', () async {
        Logiq.e('TEST', 'Error message');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Error message'));
      });

      test('should log fatal message', () async {
        Logiq.f('TEST', 'Fatal message');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Fatal message'));
      });

      test('should log with context', () async {
        Logiq.i('TEST', 'Message with context', {'key': 'value', 'num': 42});

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Message with context'));
        expect(content, logContains('key'));
        expect(content, logContains('value'));
      });

      test('should log without context', () async {
        Logiq.i('TEST', 'Message without context');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Message without context'));
      });

      test('should respect minimum log level', () async {
        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            minLevel: LogLevel.warning,
          ),
        );

        Logiq.d('TEST', 'Debug should not appear');
        Logiq.i('TEST', 'Info should not appear');
        Logiq.w('TEST', 'Warning should appear');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, isNot(logContains('Debug should not appear')));
        expect(content, isNot(logContains('Info should not appear')));
        expect(content, logContains('Warning should appear'));
      });

      test('should include session ID', () async {
        Logiq.i('TEST', 'Test message');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, contains('sess_'));
      });

      test('should auto-increment sequence numbers', () async {
        Logiq.i('TEST', 'Message 1');
        Logiq.i('TEST', 'Message 2');
        Logiq.i('TEST', 'Message 3');

        await Logiq.flush();

        final stats = await Logiq.getStats();
        expect(stats.totalLogged, 3);
      });
    });

    group('buffer management', () {
      test('should buffer logs in memory before flush', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            bufferSize: 100,
            flushInterval: const Duration(hours: 1), // Don't auto-flush
          ),
        );

        Logiq.i('TEST', 'Buffered message');

        // Should be in buffer, not yet written
        final stats = await Logiq.getStats();
        expect(stats.bufferedCount, greaterThan(0));
      });

      test('should auto-flush when buffer is full', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            bufferSize: 5, // Small buffer
            flushInterval: const Duration(hours: 1),
          ),
        );

        // Fill buffer
        for (var i = 0; i < 10; i++) {
          Logiq.i('TEST', 'Message $i');
        }

        // Wait for async flush
        await TestHelpers.waitFor(
          () async {
            final file = File('$logDirectory/current.log');
            return await file.exists();
          },
          timeout: const Duration(seconds: 5),
        );

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, isNotEmpty);
      });

      test('should handle buffer overflow by dropping oldest', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            bufferSize: 10, // Small buffer
            flushInterval: const Duration(hours: 1), // Don't auto-flush
          ),
        );

        // Overflow buffer
        for (var i = 0; i < 20; i++) {
          Logiq.i('TEST', 'Message $i');
        }

        final stats = await Logiq.getStats();
        expect(stats.droppedCount, greaterThan(0));
      });

      test('should immediately flush critical logs (error)', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            flushInterval: const Duration(hours: 1),
          ),
        );

        Logiq.e('TEST', 'Critical error');

        // Should flush immediately
        await TestHelpers.waitFor(
          () async {
            final file = File('$logDirectory/current.log');
            if (!await file.exists()) return false;
            final content = await file.readAsString();
            return content.contains('Critical error');
          },
          timeout: const Duration(seconds: 5),
        );

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Critical error'));
      });

      test('should immediately flush critical logs (fatal)', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            flushInterval: const Duration(hours: 1),
          ),
        );

        Logiq.f('TEST', 'Fatal error');

        await TestHelpers.waitFor(
          () async {
            final file = File('$logDirectory/current.log');
            if (!await file.exists()) return false;
            final content = await file.readAsString();
            return content.contains('Fatal error');
          },
          timeout: const Duration(seconds: 5),
        );

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Fatal error'));
      });
    });

    group('flush operations', () {
      setUp(() async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            flushInterval: const Duration(hours: 1), // Don't auto-flush
          ),
        );
      });

      test('should manually flush logs', () async {
        Logiq.i('TEST', 'Manual flush test');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Manual flush test'));
      });

      test('should clear buffer after flush', () async {
        Logiq.i('TEST', 'Test message');

        final beforeFlush = await Logiq.getStats();
        expect(beforeFlush.bufferedCount, greaterThan(0));

        await Logiq.flush();

        final afterFlush = await Logiq.getStats();
        expect(afterFlush.bufferedCount, 0);
      });

      test('should handle empty buffer flush', () async {
        expect(() => Logiq.flush(), returnsNormally);
      });

      test('should not flush while already flushing', () async {
        Logiq.i('TEST', 'Message');

        // Trigger multiple flushes
        final futures = [
          Logiq.flush(),
          Logiq.flush(),
          Logiq.flush(),
        ];

        await Future.wait(futures);

        // Should complete without error
        expect(futures, everyElement(completes));
      });
    });

    group('context providers', () {
      test('should inject context from providers', () async {
        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            contextProviders: [
              () => {'appVersion': '1.0.0'},
              () => {'environment': 'test'},
            ],
          ),
        );

        Logiq.i('TEST', 'Message with auto-context');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('appVersion'));
        expect(content, logContains('1.0.0'));
        expect(content, logContains('environment'));
      });

      test('should merge manual context with auto-context', () async {
        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            contextProviders: [
              () => {'auto': 'value'},
            ],
          ),
        );

        Logiq.i('TEST', 'Message', {'manual': 'data'});

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('auto'));
        expect(content, logContains('manual'));
      });

      test('should handle context provider errors gracefully', () async {
        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            contextProviders: [
              () => throw Exception('Provider error'),
              () => {'working': 'provider'},
            ],
          ),
        );

        // Should not throw
        expect(() => Logiq.i('TEST', 'Message'), returnsNormally);

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('working'));
      });
    });

    group('hooks', () {
      test('should call onLog hook', () async {
        var logCount = 0;
        LogEntry? capturedEntry;

        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            hooks: LogHooks(
              onLog: (entry) {
                logCount++;
                capturedEntry = entry;
              },
            ),
          ),
        );

        Logiq.i('TEST', 'Hook test');

        expect(logCount, 1);
        expect(capturedEntry?.message, 'Hook test');
      });

      test('should call onFlush hook', () async {
        var flushCount = 0;
        var entriesCount = 0;

        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            hooks: LogHooks(
              onFlush: (count) {
                flushCount++;
                entriesCount = count;
              },
            ),
          ),
        );

        Logiq.i('TEST', 'Message 1');
        Logiq.i('TEST', 'Message 2');

        await Logiq.flush();

        expect(flushCount, 1);
        expect(entriesCount, 2);
      });

      test('should call onError hook on write failure', () async {
        var errorCount = 0;
        Object? capturedError;

        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: '/invalid/readonly/path',
            hooks: LogHooks(
              onError: (error, stackTrace) {
                errorCount++;
                capturedError = error;
              },
            ),
          ),
        );

        Logiq.i('TEST', 'Test message');

        await Logiq.flush();

        // Should have called onError
        await TestHelpers.waitFor(
          () async => errorCount > 0,
          timeout: const Duration(seconds: 5),
        );

        expect(errorCount, greaterThan(0));
        expect(capturedError, isNotNull);
      });
    });

    group('sinks', () {
      test('should write to console sink', () async {
        final testSink = TestLogSink();

        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            sinks: [testSink],
          ),
        );

        Logiq.i('TEST', 'Console message');

        expect(testSink.entries.length, 1);
        expect(testSink.entries.first.message, 'Console message');
      });

      test('should write to multiple sinks', () async {
        final sink1 = TestLogSink();
        final sink2 = TestLogSink();

        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            sinks: [sink1, sink2],
          ),
        );

        Logiq.i('TEST', 'Multi-sink message');

        expect(sink1.entries.length, 1);
        expect(sink2.entries.length, 1);
      });

      test('should handle sink errors gracefully', () async {
        final errorSink = TestLogSink(shouldThrow: true);

        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            sinks: [errorSink],
          ),
        );

        // Should not throw even if sink throws
        expect(() => Logiq.i('TEST', 'Message'), returnsNormally);
      });
    });

    group('runtime configuration', () {
      setUp(() async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            minLevel: LogLevel.verbose,
          ),
        );
      });

      test('should change minimum log level at runtime', () async {
        Logiq.setMinLevel(LogLevel.error);

        Logiq.i('TEST', 'Info should not appear');
        Logiq.e('TEST', 'Error should appear');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, isNot(logContains('Info should not appear')));
        expect(content, logContains('Error should appear'));
      });

      test('should enable/disable logging at runtime', () async {
        Logiq.setEnabled(false);

        Logiq.i('TEST', 'Should not be logged');

        final stats = await Logiq.getStats();
        expect(stats.bufferedCount, 0);

        Logiq.setEnabled(true);

        Logiq.i('TEST', 'Should be logged');

        final newStats = await Logiq.getStats();
        expect(newStats.bufferedCount, greaterThan(0));
      });

      test('should check if logging is enabled', () async {
        expect(Logiq.isEnabled, isTrue);

        Logiq.setEnabled(false);
        expect(Logiq.isEnabled, isFalse);

        Logiq.setEnabled(true);
        expect(Logiq.isEnabled, isTrue);
      });

      test('should add redaction pattern at runtime', () async {
        Logiq.addRedaction(RedactionPattern.email);

        Logiq.i('TEST', 'Email: user@example.com');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');

        expect(content, logContains('[EMAIL_REDACTED]'));
        expect(content, isNot(logContains('user@example.com')));
      });

      test('should enter sensitive mode', () async {
        Logiq.enterSensitiveMode();

        Logiq.i('TEST', 'Sensitive data');

        final stats = await Logiq.getStats();
        expect(stats.bufferedCount, 0); // Not logged

        Logiq.exitSensitiveMode();

        Logiq.i('TEST', 'Normal data');

        final newStats = await Logiq.getStats();
        expect(newStats.bufferedCount, greaterThan(0));
      });

      test('should execute callback in sensitive mode', () async {
        var result = '';

        await Logiq.sensitive(() async {
          Logiq.i('TEST', 'Should not log');
          result = 'completed';
        });

        expect(result, 'completed');

        final stats = await Logiq.getStats();
        expect(stats.bufferedCount, 0); // Nothing logged
      });

      test('should resume logging after sensitive callback', () async {
        await Logiq.sensitive(() async {
          Logiq.i('TEST', 'Not logged');
        });

        // Should be able to log after
        Logiq.i('TEST', 'Should log');

        final stats = await Logiq.getStats();
        expect(stats.bufferedCount, greaterThan(0));
      });
    });

    group('statistics', () {
      setUp(() async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );
      });

      test('should track total logged count', () async {
        Logiq.i('TEST', 'Message 1');
        Logiq.i('TEST', 'Message 2');
        Logiq.i('TEST', 'Message 3');

        final stats = await Logiq.getStats();
        expect(stats.totalLogged, 3);
      });

      test('should track buffered count', () async {
        await Logiq.dispose();
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            flushInterval: const Duration(hours: 1), // Don't auto-flush
          ),
        );

        Logiq.i('TEST', 'Buffered 1');
        Logiq.i('TEST', 'Buffered 2');

        final stats = await Logiq.getStats();
        expect(stats.bufferedCount, 2);
      });

      test('should track session ID', () async {
        final stats = await Logiq.getStats();
        expect(stats.sessionId, isNotEmpty);
        expect(stats.sessionId, startsWith('sess_'));
      });

      test('should track storage used', () async {
        Logiq.i('TEST', 'Message with some content');

        await Logiq.flush();

        final stats = await Logiq.getStats();
        expect(stats.storageUsed, greaterThan(0));
      });

      test('should track file count', () async {
        Logiq.i('TEST', 'Message');

        await Logiq.flush();

        final stats = await Logiq.getStats();
        expect(stats.fileCount, greaterThan(0));
      });

      test('should format storage size', () async {
        Logiq.i('TEST', 'Content');

        await Logiq.flush();

        final stats = await Logiq.getStats();
        expect(stats.formattedStorageSize, isNotEmpty);
      });
    });

    group('clear operations', () {
      setUp(() async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );
      });

      test('should clear all logs', () async {
        Logiq.i('TEST', 'Message to be cleared');

        await Logiq.flush();

        final statsBefore = await Logiq.getStats();
        expect(statsBefore.fileCount, greaterThan(0));

        await Logiq.clear();

        final statsAfter = await Logiq.getStats();
        expect(statsAfter.fileCount, 0);
        expect(statsAfter.bufferedCount, 0);
      });

      test('should clear old logs', () async {
        // Create old log file manually
        final oldFile = File('$logDirectory/old.log');
        await oldFile.create(recursive: true);
        await oldFile
            .setLastModified(DateTime.now().subtract(const Duration(days: 10)));

        await Logiq.clearOlderThan(const Duration(days: 7));

        expect(await oldFile.exists(), isFalse);
      });

      test('should preserve recent logs when clearing old', () async {
        Logiq.i('TEST', 'Recent message');
        await Logiq.flush();

        await Logiq.clearOlderThan(const Duration(days: 7));

        final currentFile = File('$logDirectory/current.log');
        expect(currentFile, await fileExists());
      });
    });

    group('export operations', () {
      setUp(() async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );
      });

      test('should export logs to file', () async {
        Logiq.i('TEST', 'Exportable message');
        await Logiq.flush();

        final result = await Logiq.export();

        expect(result.file, await fileExists());
        expect(result.entryCount, greaterThan(0));
      });

      test('should compress exported logs', () async {
        Logiq.i('TEST', 'Message to compress');
        await Logiq.flush();

        final result = await Logiq.export(compress: true);

        expect(result.file.path, endsWith('.gz'));
        expect(result.compressedSize, lessThan(result.originalSize));
      });

      test('should export without compression', () async {
        Logiq.i('TEST', 'Uncompressed export');
        await Logiq.flush();

        final result = await Logiq.export(compress: false);

        expect(result.file.path, endsWith('.log'));
        expect(result.compressedSize, result.originalSize);
      });

      test('should flush before export', () async {
        Logiq.i('TEST', 'Buffered message');

        // Don't manually flush
        final result = await Logiq.export();

        // Should still include buffered message
        expect(result.entryCount, greaterThan(0));
      });
    });

    group('dispose', () {
      test('should dispose cleanly', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('TEST', 'Message before dispose');

        expect(() => Logiq.dispose(), returnsNormally);
      });

      test('should flush logs on dispose', () async {
        await Logiq.init(
          config: LogConfig(
            directory: logDirectory,
            flushInterval: const Duration(hours: 1), // Don't auto-flush
          ),
        );

        Logiq.i('TEST', 'Message before dispose');

        await Logiq.dispose();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Message before dispose'));
      });

      test('should allow re-initialization after dispose', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        await Logiq.dispose();

        // Should be able to initialize again
        expect(
          () => Logiq.init(
            config: LogConfig(directory: logDirectory),
          ),
          returnsNormally,
        );
      });
    });

    group('edge cases', () {
      test('should handle very long messages', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        final longMessage = 'x' * 10000;
        Logiq.i('TEST', longMessage);

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        // Message should be truncated to 5000 chars
        expect(content, contains('x' * 5000));
        expect(content, contains('[truncated]'));
        expect(
            content, isNot(contains(longMessage))); // Full message not present
      });

      test('should handle unicode characters', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('TEST', '🎉 Hello 世界 مرحبا');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('🎉 Hello 世界 مرحبا'));
      });

      test('should handle rapid successive logs', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        for (var i = 0; i < 1000; i++) {
          Logiq.i('TEST', 'Rapid message $i');
        }

        final stats = await Logiq.getStats();
        expect(stats.totalLogged, 1000);
      });

      test('should handle large context objects', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        final largeContext = Map.fromIterables(
          List.generate(100, (i) => 'key$i'),
          List.generate(100, (i) => 'value$i'),
        );

        Logiq.i('TEST', 'Large context', largeContext);

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Large context'));
      });

      test('should handle null values in context', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('TEST', 'Null context', {'key': null});

        expect(() => Logiq.flush(), returnsNormally);
      });

      test('should handle empty category', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('', 'Empty category');

        await Logiq.flush();

        final content =
            await TestHelpers.readLogFile('$logDirectory/current.log');
        expect(content, logContains('Empty category'));
      });

      test('should handle empty message', () async {
        await Logiq.init(
          config: LogConfig(directory: logDirectory),
        );

        Logiq.i('TEST', '');

        expect(() => Logiq.flush(), returnsNormally);
      });
    });
  });
}
